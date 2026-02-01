/**
 * SP Transit - Web Application
 * Interactive map and transit information viewer
 */

// API Configuration
// Use relative path from web folder to api folder
const API_BASE = '/api';

// Default location (Praça da Sé, São Paulo)
const DEFAULT_LOCATION = {
    lat: -23.5503,
    lng: -46.6340
};

// São Paulo bounding box (approximate)
const SAO_PAULO_BOUNDS = {
    minLat: -24.1,
    maxLat: -23.2,
    minLng: -47.2,
    maxLng: -46.3
};

// App State
const state = {
    map: null,
    userMarker: null,
    searchMarker: null,
    stopMarkers: [],
    routeLayer: null,
    currentLocation: null,
    stops: [],
    selectedStop: null
};

// DOM Elements
const elements = {
    searchInput: document.getElementById('searchInput'),
    clearSearch: document.getElementById('clearSearch'),
    searchResults: document.getElementById('searchResults'),
    locationBtn: document.getElementById('locationBtn'),
    refreshBtn: document.getElementById('refreshBtn'),
    stopsContainer: document.getElementById('stopsContainer'),
    panelTitle: document.getElementById('panelTitle'),
    stopModal: document.getElementById('stopModal'),
    modalStopName: document.getElementById('modalStopName'),
    modalContent: document.getElementById('modalContent'),
    closeModal: document.getElementById('closeModal'),
    tripModal: document.getElementById('tripModal'),
    tripModalTitle: document.getElementById('tripModalTitle'),
    tripModalContent: document.getElementById('tripModalContent'),
    closeTripModal: document.getElementById('closeTripModal')
};

// Initialize Application
document.addEventListener('DOMContentLoaded', init);

function init() {
    initMap();
    initEventListeners();
    getUserLocation();
}

// Initialize Map
function initMap() {
    state.map = L.map('map').setView([DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lng], 15);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(state.map);

    // Click on map to search nearby
    state.map.on('click', (e) => {
        const { lat, lng } = e.latlng;

        // Hide the map hint after first click
        const mapHint = document.getElementById('mapHint');
        if (mapHint) {
            mapHint.style.display = 'none';
        }

        // Check if within São Paulo
        if (!isWithinSaoPaulo(lat, lng)) {
            showToast('Local fora da área de cobertura de São Paulo');
            return;
        }

        // Add/update search marker
        if (state.searchMarker) {
            state.searchMarker.setLatLng([lat, lng]);
        } else {
            const searchIcon = L.divIcon({
                className: 'search-marker',
                iconSize: [24, 24],
                iconAnchor: [12, 12],
                html: `<svg viewBox="0 0 24 24" fill="#2563eb" stroke="white" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <circle cx="12" cy="12" r="4" fill="white"/>
                </svg>`
            });
            state.searchMarker = L.marker([lat, lng], { icon: searchIcon })
                .addTo(state.map)
                .bindPopup('Buscando paradas aqui...');
        }

        showToast('Buscando paradas neste local...');
        loadNearbyStops(lat, lng);
    });
}

// Initialize Event Listeners
function initEventListeners() {
    // Search
    elements.searchInput.addEventListener('input', debounce(handleSearch, 300));
    elements.searchInput.addEventListener('focus', () => {
        if (elements.searchInput.value.length >= 2) {
            elements.searchResults.classList.remove('hidden');
        }
    });
    elements.clearSearch.addEventListener('click', clearSearch);

    // Close search results when clicking outside
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.search-container')) {
            elements.searchResults.classList.add('hidden');
        }
    });

    // Location button
    elements.locationBtn.addEventListener('click', getUserLocation);

    // Refresh button
    elements.refreshBtn.addEventListener('click', refreshStops);

    // Modals
    elements.closeModal.addEventListener('click', closeStopModal);
    elements.closeTripModal.addEventListener('click', closeTripModal);
    elements.stopModal.addEventListener('click', (e) => {
        if (e.target === elements.stopModal) closeStopModal();
    });
    elements.tripModal.addEventListener('click', (e) => {
        if (e.target === elements.tripModal) closeTripModal();
    });
}

// Check if location is within São Paulo
function isWithinSaoPaulo(lat, lng) {
    return lat >= SAO_PAULO_BOUNDS.minLat &&
           lat <= SAO_PAULO_BOUNDS.maxLat &&
           lng >= SAO_PAULO_BOUNDS.minLng &&
           lng <= SAO_PAULO_BOUNDS.maxLng;
}

// Get User Location
function getUserLocation() {
    if (!navigator.geolocation) {
        showToast('Geolocalização não suportada. Usando Praça da Sé.');
        useDefaultLocation();
        return;
    }

    elements.locationBtn.classList.add('loading');

    navigator.geolocation.getCurrentPosition(
        (position) => {
            const { latitude, longitude } = position.coords;

            elements.locationBtn.classList.remove('loading');

            // Check if user is within São Paulo
            if (!isWithinSaoPaulo(latitude, longitude)) {
                showToast('Você está fora de São Paulo. Mostrando Praça da Sé.');
                useDefaultLocation();
                return;
            }

            state.currentLocation = { lat: latitude, lng: longitude };

            // Update map view
            state.map.setView([latitude, longitude], 16);

            // Add/update user marker
            if (state.userMarker) {
                state.userMarker.setLatLng([latitude, longitude]);
            } else {
                const userIcon = L.divIcon({
                    className: 'user-marker',
                    iconSize: [20, 20],
                    iconAnchor: [10, 10]
                });
                state.userMarker = L.marker([latitude, longitude], { icon: userIcon })
                    .addTo(state.map)
                    .bindPopup('Você está aqui');
            }

            loadNearbyStops(latitude, longitude);
        },
        (error) => {
            elements.locationBtn.classList.remove('loading');
            console.error('Geolocation error:', error);
            showToast('Não foi possível obter sua localização. Usando Praça da Sé.');
            useDefaultLocation();
        },
        { enableHighAccuracy: true, timeout: 10000 }
    );
}

// Use default location (Praça da Sé)
function useDefaultLocation() {
    state.currentLocation = { lat: DEFAULT_LOCATION.lat, lng: DEFAULT_LOCATION.lng };
    state.map.setView([DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lng], 16);
    loadNearbyStops(DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lng);
}

// Load Nearby Stops
async function loadNearbyStops(lat, lng) {
    showLoading(elements.stopsContainer);
    elements.panelTitle.textContent = 'Paradas Próximas';

    try {
        const url = `${API_BASE}/nearby.php?lat=${lat}&lon=${lng}&limit=20&include_arrivals=1`;
        console.log('Fetching:', url);

        const response = await fetch(url);

        // Check if response is ok
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        // Get raw text first to debug
        const text = await response.text();
        console.log('Response text:', text.substring(0, 500));

        // Try to parse as JSON
        let data;
        try {
            data = JSON.parse(text);
        } catch (parseError) {
            console.error('JSON Parse Error. Raw response:', text);
            throw new Error('API não retornou JSON válido. Verifique o console.');
        }

        // Check for API error
        if (data.error) {
            throw new Error(data.message || data.error);
        }

        state.stops = data.stops || [];
        renderStops(state.stops);
        renderStopMarkers(state.stops);

        // Pan map to show all markers
        if (state.stops.length > 0) {
            const bounds = L.latLngBounds(state.stops.map(s => [s.lat, s.lon]));
            if (state.currentLocation) {
                bounds.extend([state.currentLocation.lat, state.currentLocation.lng]);
            }
            state.map.fitBounds(bounds, { padding: [50, 50] });
        }

    } catch (error) {
        console.error('Error loading nearby stops:', error);
        showToast('Erro ao carregar paradas: ' + error.message, 'error');
        elements.stopsContainer.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M12 8v4m0 4h.01"/>
                </svg>
                <h3>Erro ao carregar</h3>
                <p>${escapeHtml(error.message)}</p>
            </div>
        `;
    }
}

// Render Stops List
function renderStops(stops) {
    if (stops.length === 0) {
        elements.stopsContainer.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8Z"/>
                    <path d="M12 6v6l4 2"/>
                </svg>
                <h3>Nenhuma parada encontrada</h3>
                <p>Tente buscar em outra localização</p>
            </div>
        `;
        return;
    }

    elements.stopsContainer.innerHTML = stops.map(stop => `
        <div class="stop-card" data-stop-id="${stop.id}" onclick="openStopModal('${stop.id}')">
            <div class="stop-card-header">
                <div class="stop-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="3" width="18" height="18" rx="2"/>
                        <path d="M9 17V7h4a3 3 0 0 1 0 6H9"/>
                    </svg>
                </div>
                <div class="stop-info">
                    <div class="stop-name">${escapeHtml(stop.name)}</div>
                    <div class="stop-distance">${formatDistance(stop.distance)}</div>
                </div>
            </div>
            ${stop.arrivals && stop.arrivals.length > 0 ? `
                <div class="stop-routes">
                    ${stop.arrivals.slice(0, 4).map(arrival => `
                        <span class="route-badge" style="background-color: #${arrival.routeColor || '64748b'}">
                            ${escapeHtml(arrival.routeShortName)} - ${arrival.waitTime}min
                        </span>
                    `).join('')}
                </div>
            ` : ''}
        </div>
    `).join('');
}

// Render Stop Markers on Map
function renderStopMarkers(stops) {
    // Clear existing markers
    state.stopMarkers.forEach(marker => marker.remove());
    state.stopMarkers = [];

    stops.forEach(stop => {
        const icon = L.divIcon({
            className: 'custom-marker',
            iconSize: [14, 14],
            iconAnchor: [7, 7]
        });

        const marker = L.marker([stop.lat, stop.lon], { icon })
            .addTo(state.map)
            .bindPopup(`
                <div class="popup-stop-name">${escapeHtml(stop.name)}</div>
                <div class="popup-stop-routes">${stop.routes || 'Carregando linhas...'}</div>
                <button class="popup-btn" onclick="openStopModal('${stop.id}')">
                    Ver horários
                </button>
            `);

        state.stopMarkers.push(marker);
    });
}

// Search Functionality
async function handleSearch() {
    const query = elements.searchInput.value.trim();

    if (query.length < 2) {
        elements.searchResults.classList.add('hidden');
        elements.clearSearch.classList.add('hidden');
        return;
    }

    elements.clearSearch.classList.remove('hidden');

    try {
        const url = `${API_BASE}/search.php?q=${encodeURIComponent(query)}&limit=10`;
        console.log('Search URL:', url);

        const response = await fetch(url);
        const text = await response.text();
        console.log('Search response:', text.substring(0, 300));

        let data;
        try {
            data = JSON.parse(text);
        } catch (parseError) {
            console.error('Search JSON parse error:', text);
            return;
        }

        if (data.error) {
            console.error('Search API error:', data);
            return;
        }

        renderSearchResults(data.stops || []);
    } catch (error) {
        console.error('Search error:', error);
    }
}

function renderSearchResults(stops) {
    if (stops.length === 0) {
        elements.searchResults.innerHTML = `
            <div class="search-result-item">
                <div class="search-result-name">Nenhum resultado encontrado</div>
            </div>
        `;
    } else {
        elements.searchResults.innerHTML = stops.map(stop => `
            <div class="search-result-item" onclick="selectSearchResult('${stop.stopId}', ${stop.stopLat}, ${stop.stopLon})">
                <div class="search-result-name">${escapeHtml(stop.stopName)}</div>
                <div class="search-result-routes">${stop.routes || ''}</div>
            </div>
        `).join('');
    }

    elements.searchResults.classList.remove('hidden');
}

function selectSearchResult(stopId, lat, lon) {
    elements.searchResults.classList.add('hidden');
    elements.searchInput.value = '';
    elements.clearSearch.classList.add('hidden');

    state.map.setView([lat, lon], 17);
    loadNearbyStops(lat, lon);

    setTimeout(() => openStopModal(stopId), 500);
}

function clearSearch() {
    elements.searchInput.value = '';
    elements.clearSearch.classList.add('hidden');
    elements.searchResults.classList.add('hidden');
}

// Stop Modal
async function openStopModal(stopId) {
    elements.stopModal.classList.remove('hidden');
    elements.modalContent.innerHTML = `
        <div class="loading-state">
            <div class="spinner"></div>
            <p>Carregando horários...</p>
        </div>
    `;

    try {
        const response = await fetch(`${API_BASE}/arrivals.php?stop_id=${stopId}&limit=15`);
        const data = await response.json();

        // Get stop name
        const stopResponse = await fetch(`${API_BASE}/stop.php?stop_id=${stopId}`);
        const stopData = await stopResponse.json();

        elements.modalStopName.textContent = stopData.stop?.stopName || `Parada ${stopId}`;
        state.selectedStop = stopData.stop;

        renderArrivals(data.arrivals || []);
    } catch (error) {
        console.error('Error loading arrivals:', error);
        elements.modalContent.innerHTML = `
            <div class="empty-state">
                <h3>Erro ao carregar horários</h3>
                <p>Tente novamente mais tarde</p>
            </div>
        `;
    }
}

function renderArrivals(arrivals) {
    if (arrivals.length === 0) {
        elements.modalContent.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M12 6v6l4 2"/>
                </svg>
                <h3>Nenhum ônibus previsto</h3>
                <p>Não há previsões para este horário</p>
            </div>
        `;
        return;
    }

    elements.modalContent.innerHTML = arrivals.map(arrival => {
        const waitClass = arrival.waitTime <= 5 ? 'now' : arrival.waitTime <= 10 ? 'soon' : '';
        const bgColor = arrival.routeColor || '64748b';

        return `
            <div class="arrival-card" onclick="openTripModal('${arrival.tripId}')">
                <div class="arrival-route" style="background-color: #${bgColor}">
                    ${escapeHtml(arrival.routeShortName)}
                </div>
                <div class="arrival-info">
                    <div class="arrival-headsign">${escapeHtml(arrival.headsign || arrival.routeLongName)}</div>
                    <div class="arrival-time-row">
                        <span>${arrival.arrivalTime}</span>
                        ${arrival.frequency ? `<span>• A cada ${arrival.frequency} min</span>` : ''}
                    </div>
                </div>
                <div class="arrival-wait ${waitClass}">
                    ${arrival.waitTime}min
                </div>
            </div>
        `;
    }).join('');
}

function closeStopModal() {
    elements.stopModal.classList.add('hidden');
}

// Trip Modal
async function openTripModal(tripId) {
    elements.tripModal.classList.remove('hidden');
    elements.tripModalContent.innerHTML = `
        <div class="loading-state">
            <div class="spinner"></div>
            <p>Carregando rota...</p>
        </div>
    `;

    try {
        const response = await fetch(`${API_BASE}/trip.php?trip_id=${tripId}`);
        const data = await response.json();

        if (data.trip) {
            renderTripDetails(data.trip);
            loadTripShape(data.trip.shapeId);
        } else {
            throw new Error('Trip not found');
        }
    } catch (error) {
        console.error('Error loading trip:', error);
        elements.tripModalContent.innerHTML = `
            <div class="empty-state">
                <h3>Erro ao carregar rota</h3>
                <p>Tente novamente mais tarde</p>
            </div>
        `;
    }
}

function renderTripDetails(trip) {
    elements.tripModalTitle.textContent = trip.headsign || 'Detalhes da Linha';

    const stopsHtml = trip.stops.map((stop, index) => {
        const isFirst = index === 0;
        const isLast = index === trip.stops.length - 1;
        const itemClass = isFirst ? 'first' : isLast ? 'last' : '';

        return `
            <div class="trip-stop-item ${itemClass}">
                <div class="trip-stop-name">${escapeHtml(stop.stopName)}</div>
                <div class="trip-stop-time">${stop.arrivalTime}</div>
            </div>
        `;
    }).join('');

    elements.tripModalContent.innerHTML = `
        <div class="trip-info-header">
            <div class="trip-route-badge" style="background-color: #509E2F">
                ${escapeHtml(trip.routeId)}
            </div>
            <div class="trip-details">
                <h3>${escapeHtml(trip.headsign)}</h3>
                <p>${trip.stops.length} paradas</p>
            </div>
        </div>
        <div class="trip-stops-list">
            ${stopsHtml}
        </div>
    `;
}

async function loadTripShape(shapeId) {
    if (!shapeId) return;

    try {
        const response = await fetch(`${API_BASE}/shape.php?shape_id=${shapeId}&format=geojson`);
        const geojson = await response.json();

        // Remove existing route layer
        if (state.routeLayer) {
            state.routeLayer.remove();
        }

        // Add new route layer
        state.routeLayer = L.geoJSON(geojson, {
            style: {
                color: '#2563eb',
                weight: 4,
                opacity: 0.8
            }
        }).addTo(state.map);

        // Fit map to route
        state.map.fitBounds(state.routeLayer.getBounds(), { padding: [50, 50] });
    } catch (error) {
        console.error('Error loading shape:', error);
    }
}

function closeTripModal() {
    elements.tripModal.classList.add('hidden');

    // Remove route layer
    if (state.routeLayer) {
        state.routeLayer.remove();
        state.routeLayer = null;
    }
}

// Refresh Stops
function refreshStops() {
    elements.refreshBtn.classList.add('loading');

    const location = state.currentLocation || DEFAULT_LOCATION;
    loadNearbyStops(location.lat, location.lng).finally(() => {
        elements.refreshBtn.classList.remove('loading');
    });
}

// Utility Functions
function showLoading(container) {
    container.innerHTML = `
        <div class="loading-state">
            <div class="spinner"></div>
            <p>Carregando...</p>
        </div>
    `;
}

function showError(message) {
    showToast(message, 'error');
}

function showToast(message, type = 'info') {
    // Remove existing toast
    const existingToast = document.querySelector('.toast');
    if (existingToast) {
        existingToast.remove();
    }

    // Create toast element
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
        <span>${message}</span>
        <button onclick="this.parentElement.remove()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 6L6 18M6 6l12 12"></path>
            </svg>
        </button>
    `;

    document.body.appendChild(toast);

    // Auto remove after 4 seconds
    setTimeout(() => {
        if (toast.parentElement) {
            toast.classList.add('toast-hide');
            setTimeout(() => toast.remove(), 300);
        }
    }, 4000);
}

function formatDistance(distance) {
    if (!distance) return '';

    // Distance is in degrees, approximate conversion to meters
    // 1 degree ≈ 111km at equator
    const meters = distance * 111000;

    if (meters < 1000) {
        return `${Math.round(meters)}m`;
    }
    return `${(meters / 1000).toFixed(1)}km`;
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Make functions globally accessible for onclick handlers
window.openStopModal = openStopModal;
window.openTripModal = openTripModal;
window.selectSearchResult = selectSearchResult;
