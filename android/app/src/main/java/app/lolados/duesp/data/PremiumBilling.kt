package app.lolados.duesp.data

import android.app.Activity
import android.content.Context
import app.lolados.duesp.BuildConfig
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume

/** A subscription plan as shown on the Premium screen, with Play's localised price. */
data class PremiumPlan(
    val productId: String,
    val formattedPrice: String,
    /** ISO 8601 billing period of the base plan, e.g. "P1W" or "P1Y". */
    val billingPeriod: String,
    internal val details: ProductDetails,
    internal val offerToken: String,
)

sealed interface BillingStatus {
    data object Connecting : BillingStatus
    data object Ready : BillingStatus
    /** Play Billing is not available (no Play Store, signed-out account, products not set up). */
    data object Unavailable : BillingStatus
}

/**
 * Google Play Billing for Due SP Premium (`app.lolados.data.weekly` / `app.lolados.data.yearly`),
 * the Android counterpart of the iOS StoreKit store. Owned, non-suspended subscriptions grant Premium;
 * the result is cached in [PremiumAccess] so the app keeps working offline.
 */
class PremiumBilling(context: Context, private val access: PremiumAccess) : PurchasesUpdatedListener {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _plans = MutableStateFlow<List<PremiumPlan>>(emptyList())
    val plans: StateFlow<List<PremiumPlan>> = _plans.asStateFlow()

    private val _status = MutableStateFlow<BillingStatus>(BillingStatus.Connecting)
    val status: StateFlow<BillingStatus> = _status.asStateFlow()

    /** True while a purchase is pending (e.g. cash payment not completed yet). */
    private val _pending = MutableStateFlow(false)
    val pending: StateFlow<Boolean> = _pending.asStateFlow()

    private val client = BillingClient.newBuilder(context.applicationContext)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().enablePrepaidPlans().build())
        .enableAutoServiceReconnection()
        .build()

    /** Serialises refreshes: two concurrent connection attempts make Play Billing fail both. */
    private val refreshLock = Mutex()

    /** Connects (once) and refreshes plans and entitlement. Safe to call repeatedly. */
    fun refresh() {
        scope.launch {
            refreshLock.withLock {
                if (!connect()) {
                    _status.value = BillingStatus.Unavailable
                    return@withLock
                }
                loadPlans()
                syncPurchases()
            }
        }
    }

    /** Starts the Play purchase sheet for [plan]. */
    fun purchase(activity: Activity, plan: PremiumPlan) {
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(plan.details)
                        .setOfferToken(plan.offerToken)
                        .build(),
                ),
            )
            .build()
        client.launchBillingFlow(activity, params)
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            scope.launch { applyPurchases(purchases) }
        } else if (result.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            scope.launch { syncPurchases() }
        }
    }

    private suspend fun connect(): Boolean {
        if (client.isReady) return true
        return suspendCancellableCoroutine { cont ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (cont.isActive) cont.resume(result.responseCode == BillingClient.BillingResponseCode.OK)
                }

                override fun onBillingServiceDisconnected() {
                    if (cont.isActive) cont.resume(false)
                }
            })
        }
    }

    private suspend fun loadPlans() {
        val products = listOf(PremiumAccess.PRODUCT_WEEKLY, PremiumAccess.PRODUCT_YEARLY).map {
            QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.SUBS).build()
        }
        val details = suspendCancellableCoroutine { cont ->
            client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(products).build()) { result, response ->
                val list = if (result.responseCode == BillingClient.BillingResponseCode.OK) response.productDetailsList else emptyList()
                if (cont.isActive) cont.resume(list)
            }
        }
        _plans.value = details.mapNotNull(::toPlan).sortedBy { if (it.productId == PremiumAccess.PRODUCT_YEARLY) 1 else 0 }
        _status.value = if (_plans.value.isEmpty()) BillingStatus.Unavailable else BillingStatus.Ready
    }

    private suspend fun syncPurchases() {
        val (result, purchases) = suspendCancellableCoroutine { cont ->
            client.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
            ) { result, purchases -> if (cont.isActive) cont.resume(result to purchases) }
        }
        if (result.responseCode == BillingClient.BillingResponseCode.OK) applyPurchases(purchases, replace = true)
    }

    /**
     * Grants Premium for purchased, non-suspended subscriptions and acknowledges new ones (Play refunds
     * purchases that are not acknowledged within 3 days). With [replace], an empty result revokes Premium,
     * except in debug builds, where the local toggle is kept for testing outside Play.
     */
    private suspend fun applyPurchases(purchases: List<Purchase>, replace: Boolean = false) {
        val ours = purchases.filter { p ->
            p.products.any { it == PremiumAccess.PRODUCT_WEEKLY || it == PremiumAccess.PRODUCT_YEARLY }
        }
        val active = ours.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED && !it.isSuspended }
        _pending.value = ours.any { it.purchaseState == Purchase.PurchaseState.PENDING }
        active.filterNot { it.isAcknowledged }.forEach { acknowledge(it) }
        when {
            active.isNotEmpty() -> access.setPremium(true)
            replace && !BuildConfig.DEBUG -> access.setPremium(false)
        }
    }

    private suspend fun acknowledge(purchase: Purchase) {
        suspendCancellableCoroutine { cont ->
            client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()) {
                if (cont.isActive) cont.resume(Unit)
            }
        }
    }

    private fun toPlan(details: ProductDetails): PremiumPlan? {
        // Prefer the plain base plan (no offer id); fall back to the first offer Play returns.
        val offers = details.subscriptionOfferDetails ?: return null
        val offer = offers.firstOrNull { it.offerId == null } ?: offers.firstOrNull() ?: return null
        val phase = offer.pricingPhases.pricingPhaseList.lastOrNull() ?: return null
        return PremiumPlan(details.productId, phase.formattedPrice, phase.billingPeriod, details, offer.offerToken)
    }

    companion object {
        /** Play's subscription management page for this app (cancel, change plan, payment method). */
        fun manageUrl(packageName: String, productId: String?): String =
            "https://play.google.com/store/account/subscriptions?package=$packageName" + (productId?.let { "&sku=$it" } ?: "")
    }
}
