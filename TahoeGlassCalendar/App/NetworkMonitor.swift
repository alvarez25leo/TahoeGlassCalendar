import Foundation
import Network
import Combine
import os

/// Observa el estado de conectividad del sistema y publica si hay una ruta de
/// red disponible. **No abre conexiones**: sólo refleja lo que reporta el
/// sistema (`NWPathMonitor`), por lo que funciona dentro del sandbox sin el
/// entitlement `com.apple.security.network.client`.
///
/// Lo consume el `CalendarViewModel` para derivar `isOffline` y mostrar el aviso
/// "sin conexión" en el header, ya que sin internet iCloud/CalDAV no sincroniza
/// y los eventos pueden quedar desactualizados.
@MainActor
final class NetworkMonitor: ObservableObject {
    /// `true` mientras el sistema reporta una ruta de red satisfactoria. Arranca
    /// optimista en `true` para no parpadear un falso "offline" en el primer
    /// frame antes de que `NWPathMonitor` entregue el primer estado.
    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.manuel.tahoeglasscalendar.network-monitor", qos: .utility)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.isConnected != connected else { return }
                self.isConnected = connected
                AppLogger.network.info("Network path changed → connected=\(connected, privacy: .public)")
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
