package app.lolados.duesp.data

import app.lolados.duesp.domain.RailMapLine
import app.lolados.duesp.domain.RailSource
import app.lolados.duesp.domain.RailStation

/**
 * Metrô and CPTM lines drawn on the main map (same sources as iOS, SaoPauloRailNetwork.swift): each line
 * comes from one GTFS trip (trip.php), with a built-in outline as fallback when the API can't be reached.
 * Fallback stations have stopId 0 (no arrivals to open).
 */
object RailNetwork {
    data class Source(val id: String, val tripId: String, val source: RailSource, val name: String, val colorHex: String)

    val sources = listOf(
        Source("L1", "METRÔ L1-0", RailSource.METRO, "Linha 1 - Azul", "0455A1"),
        Source("L2", "METRÔ L2-0", RailSource.METRO, "Linha 2 - Verde", "007E5E"),
        Source("L3", "METRÔ L3-0", RailSource.METRO, "Linha 3 - Vermelha", "EE372F"),
        Source("L4", "METRÔ L4-0", RailSource.METRO, "Linha 4 - Amarela", "FFD700"),
        Source("L5", "METRÔ L5-0", RailSource.METRO, "Linha 5 - Lilás", "9B3894"),
        Source("L7", "CPTM L07-0", RailSource.CPTM, "Linha 7 - Rubi", "CA016B"),
        Source("L8", "CPTM L08-0", RailSource.CPTM, "Linha 8 - Diamante", "97A098"),
        Source("L9", "CPTM L09-0", RailSource.CPTM, "Linha 9 - Esmeralda", "01A9A7"),
        Source("L10", "CPTM L10-0", RailSource.CPTM, "Linha 10 - Turquesa", "008B8B"),
        Source("L11", "CPTM L11-0", RailSource.CPTM, "Linha 11 - Coral", "F04E23"),
        Source("L12", "CPTM L12-0", RailSource.CPTM, "Linha 12 - Safira", "083D8B"),
        Source("L13", "CPTM L13-0", RailSource.CPTM, "Linha 13 - Jade", "00B352"),
    )

    private val fallbackStations: Map<String, List<Triple<String, Double, Double>>> = mapOf(
        "L1" to listOf(
            Triple("Jabaquara", -23.6466, -46.6408), Triple("Santa Cruz", -23.5995, -46.6367),
            Triple("Paraíso", -23.5753, -46.6400), Triple("São Joaquim", -23.5616, -46.6397),
            Triple("Sé", -23.5507, -46.6339), Triple("Luz", -23.5363, -46.6339),
            Triple("Santana", -23.5059, -46.6246), Triple("Tucuruvi", -23.4799, -46.6044),
        ),
        "L2" to listOf(
            Triple("Vila Madalena", -23.5466, -46.6906), Triple("Sumaré", -23.5508, -46.6790),
            Triple("Consolação", -23.5573, -46.6608), Triple("Brigadeiro", -23.5696, -46.6477),
            Triple("Paraíso", -23.5753, -46.6400), Triple("Ana Rosa", -23.5818, -46.6388),
            Triple("Santos-Imigrantes", -23.5923, -46.6207), Triple("Vila Prudente", -23.5859, -46.5816),
        ),
        "L3" to listOf(
            Triple("Palmeiras-Barra Funda", -23.5255, -46.6676), Triple("República", -23.5441, -46.6421),
            Triple("Sé", -23.5507, -46.6339), Triple("Brás", -23.5434, -46.6166),
            Triple("Tatuapé", -23.5403, -46.5764), Triple("Corinthians-Itaquera", -23.5421, -46.4712),
        ),
        "L4" to listOf(
            Triple("Luz", -23.5363, -46.6339), Triple("República", -23.5441, -46.6421),
            Triple("Higienópolis-Mackenzie", -23.5489, -46.6521), Triple("Paulista", -23.5550, -46.6622),
            Triple("Pinheiros", -23.5675, -46.7018), Triple("Butantã", -23.5716, -46.7084),
            Triple("Vila Sônia", -23.5861, -46.7314),
        ),
        "L5" to listOf(
            Triple("Capão Redondo", -23.6598, -46.7692), Triple("Santo Amaro", -23.6540, -46.7142),
            Triple("Adolfo Pinheiro", -23.6503, -46.7040), Triple("Alto da Boa Vista", -23.6414, -46.6991),
            Triple("Borba Gato", -23.6330, -46.6939), Triple("Santa Cruz", -23.5995, -46.6367),
            Triple("Chácara Klabin", -23.5928, -46.6297),
        ),
        "L7" to listOf(
            Triple("Jundiaí", -23.1861, -46.8845), Triple("Franco da Rocha", -23.3224, -46.7284),
            Triple("Caieiras", -23.3644, -46.7424), Triple("Perus", -23.4043, -46.7531),
            Triple("Pirituba", -23.4946, -46.7251), Triple("Lapa", -23.5257, -46.7056),
            Triple("Palmeiras-Barra Funda", -23.5255, -46.6676), Triple("Luz", -23.5363, -46.6339),
        ),
        "L8" to listOf(
            Triple("Amador Bueno", -23.5348, -47.0662), Triple("Itapevi", -23.5486, -46.9345),
            Triple("Barueri", -23.5112, -46.8760), Triple("Carapicuíba", -23.5231, -46.8352),
            Triple("Osasco", -23.5327, -46.7905), Triple("Presidente Altino", -23.5316, -46.7644),
            Triple("Palmeiras-Barra Funda", -23.5255, -46.6676), Triple("Júlio Prestes", -23.5358, -46.6430),
        ),
        "L9" to listOf(
            Triple("Osasco", -23.5327, -46.7905), Triple("Ceasa", -23.5462, -46.7422),
            Triple("Pinheiros", -23.5675, -46.7018), Triple("Cidade Jardim", -23.5756, -46.6936),
            Triple("Vila Olímpia", -23.5952, -46.6892), Triple("Santo Amaro", -23.6540, -46.7142),
            Triple("Jurubatuba", -23.6810, -46.7082), Triple("Grajaú", -23.7524, -46.6953),
        ),
        "L10" to listOf(
            Triple("Rio Grande da Serra", -23.7445, -46.4035), Triple("Mauá", -23.6679, -46.4615),
            Triple("Santo André", -23.6561, -46.5307), Triple("São Caetano do Sul", -23.6187, -46.5564),
            Triple("Tamanduateí", -23.5938, -46.5899), Triple("Brás", -23.5434, -46.6166),
        ),
        "L11" to listOf(
            Triple("Luz", -23.5363, -46.6339), Triple("Brás", -23.5434, -46.6166),
            Triple("Tatuapé", -23.5403, -46.5764), Triple("Corinthians-Itaquera", -23.5421, -46.4712),
            Triple("Guaianases", -23.5437, -46.4132), Triple("Suzano", -23.5448, -46.3097),
            Triple("Estudantes", -23.5223, -46.1904),
        ),
        "L12" to listOf(
            Triple("Brás", -23.5434, -46.6166), Triple("Tatuapé", -23.5403, -46.5764),
            Triple("Engenheiro Goulart", -23.4970, -46.5308), Triple("São Miguel Paulista", -23.4938, -46.4430),
            Triple("Itaim Paulista", -23.5017, -46.3983), Triple("Calmon Viana", -23.5362, -46.3473),
        ),
        "L13" to listOf(
            Triple("Palmeiras-Barra Funda", -23.5255, -46.6676), Triple("Luz", -23.5363, -46.6339),
            Triple("Brás", -23.5434, -46.6166), Triple("Engenheiro Goulart", -23.4970, -46.5308),
            Triple("Guarulhos-Cecap", -23.4762, -46.5250), Triple("Aeroporto-Guarulhos", -23.4354, -46.4730),
        ),
    )

    fun fallback(source: Source): RailMapLine = RailMapLine(
        id = source.id,
        name = source.name,
        source = source.source,
        colorHex = source.colorHex,
        stations = fallbackStations[source.id].orEmpty().map { (name, lat, lon) -> RailStation(0, name, lat, lon) },
    )
}
