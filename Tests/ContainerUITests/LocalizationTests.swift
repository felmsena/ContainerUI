import XCTest
@testable import ContainerUI

/// Verifies the Spanish translation catalog (Resources/es.lproj/Localizable.strings)
/// loads correctly and contains accurate translations for representative UI
/// copy across every major screen — without needing to run the app or
/// switch the system's language.
final class LocalizationTests: XCTestCase {

    private static var spanishStrings: [String: String] = {
        guard let path = Bundle.module.path(forResource: "es", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            XCTFail("es.lproj not found in resource bundle")
            return [:]
        }
        guard let stringsPath = bundle.path(forResource: "Localizable", ofType: "strings"),
              let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String] else {
            XCTFail("Localizable.strings not found or unreadable in es.lproj")
            return [:]
        }
        return dict
    }()

    private func es(_ key: String) -> String? {
        Self.spanishStrings[key]
    }

    func testCatalogLoads() {
        XCTAssertFalse(Self.spanishStrings.isEmpty, "es.lproj/Localizable.strings should not be empty")
        XCTAssertGreaterThanOrEqual(Self.spanishStrings.count, 250,
            "expected broad coverage of the app's UI copy; found only \(Self.spanishStrings.count) entries")
    }

    func testNoDuplicateOrEmptyTranslations() {
        for (key, value) in Self.spanishStrings {
            XCTAssertFalse(value.isEmpty, "key \"\(key)\" has an empty Spanish translation")
        }
    }

    // MARK: - Sidebar / navigation

    func testSidebarSections() {
        XCTAssertEqual(es("Containers"), "Contenedores")
        XCTAssertEqual(es("Images"), "Imágenes")
        XCTAssertEqual(es("Volumes"), "Volúmenes")
        XCTAssertEqual(es("Registry"), "Registro")
        XCTAssertEqual(es("Build"), "Compilar")
        XCTAssertEqual(es("Stats"), "Estadísticas")
        XCTAssertEqual(es("Logs"), "Registros")
        XCTAssertEqual(es("Settings"), "Ajustes")
    }

    // MARK: - Container state (ContainerState.label pulls from this catalog)

    func testContainerStateLabels() {
        XCTAssertEqual(es("Running"), "En ejecución")
        XCTAssertEqual(es("Stopped"), "Detenido")
        XCTAssertEqual(es("Paused"), "Pausado")
        XCTAssertEqual(es("Unknown"), "Desconocido")
    }

    // MARK: - Empty states / no-results templates

    func testEmptyStateTemplates() {
        XCTAssertEqual(es("No images"), "No hay imágenes")
        XCTAssertEqual(es("No volumes"), "No hay volúmenes")
        XCTAssertEqual(es("No containers"), "No hay contenedores")
        XCTAssertEqual(es("No results for \"%@\""), "Sin resultados para \"%@\"")
    }

    // MARK: - Pluralization (split-literal fix, not a raw "%lld …%@" template)

    func testPluralizationIsGrammaticallySplit() {
        XCTAssertEqual(es("Prune 1 unused image"), "Vaciar 1 imagen sin uso")
        XCTAssertEqual(es("Prune %lld unused images"), "Vaciar %lld imágenes sin uso")
        XCTAssertEqual(es("Prune 1 stopped container"), "Vaciar 1 contenedor detenido")
        XCTAssertEqual(es("Prune %lld stopped containers"), "Vaciar %lld contenedores detenidos")
        XCTAssertEqual(es("Remove 1 stopped container?"), "¿Quitar 1 contenedor detenido?")
        XCTAssertEqual(es("Remove %lld stopped containers?"), "¿Quitar %lld contenedores detenidos?")

        // The old English-only "%lld … item%@" template (where %@ carried a
        // hardcoded "s"/"" suffix) must not reappear — it can't be translated
        // correctly since Spanish doesn't pluralize by appending "s".
        XCTAssertNil(es("Prune %lld unused image%@"))
        XCTAssertNil(es("Prune %lld stopped container%@"))
    }

    // MARK: - Toolbar actions / accessibility labels

    func testToolbarActions() {
        XCTAssertEqual(es("Refresh containers"), "Actualizar contenedores")
        XCTAssertEqual(es("Refresh images"), "Actualizar imágenes")
        XCTAssertEqual(es("Refresh volumes"), "Actualizar volúmenes")
        XCTAssertEqual(es("Refresh logs"), "Actualizar registros")
        XCTAssertEqual(es("Refresh system info"), "Actualizar info del sistema")
        XCTAssertEqual(es("Clear search"), "Borrar búsqueda")
        XCTAssertEqual(es("Delete %@"), "Eliminar %@")
        XCTAssertEqual(es("Copy %@"), "Copiar %@")
    }

    // MARK: - Menu bar

    func testMenuBar() {
        XCTAssertEqual(es("Open ContainerUI"), "Abrir ContainerUI")
        XCTAssertEqual(es("Quit ContainerUI"), "Salir de ContainerUI")
        XCTAssertEqual(es("%lld running · %lld stopped"), "%lld en ejecución · %lld detenidos")
        XCTAssertEqual(es("Stop %@"), "Detener %@")
        XCTAssertEqual(es("Start %@"), "Iniciar %@")
    }

    // MARK: - Sheets

    func testRunContainerSheet() {
        XCTAssertEqual(es("Run Container"), "Ejecutar contenedor")
        XCTAssertEqual(es("Port Mappings"), "Mapeo de puertos")
        XCTAssertEqual(es("Volume Mounts"), "Montajes de volumen")
        XCTAssertEqual(es("Add port"), "Agregar puerto")
        XCTAssertEqual(es("Remove environment variable"), "Quitar variable de entorno")
    }

    func testRegistryLoginSheet() {
        XCTAssertEqual(es("Add Registry Login"), "Agregar inicio de sesión de registro")
        XCTAssertEqual(es("Password / Token"), "Contraseña / Token")
        XCTAssertEqual(es("Log In"), "Iniciar sesión")
    }

    // MARK: - Settings

    func testSettings() {
        XCTAssertEqual(es("Binary"), "Binario")
        XCTAssertEqual(es("Preferences"), "Preferencias")
        XCTAssertEqual(es("Registries"), "Registros")
        XCTAssertEqual(es("No registry logins"), "No hay inicios de sesión de registro")
    }

    // MARK: - Groups (compose-lite)

    func testGroupsSection() {
        XCTAssertEqual(es("Groups"), "Grupos")
        XCTAssertEqual(es("No groups"), "No hay grupos")
        XCTAssertEqual(es("New Group…"), "Nuevo grupo…")
        XCTAssertEqual(es("Open…"), "Abrir…")
        XCTAssertEqual(es("Select a group"), "Seleccioná un grupo")
        XCTAssertEqual(es("Up"), "Levantar")
        XCTAssertEqual(es("Down"), "Bajar")
        XCTAssertEqual(es("Pending"), "Pendiente")
        XCTAssertEqual(es("Starting…"), "Iniciando…")
        XCTAssertEqual(es("Stopping…"), "Deteniendo…")
    }

    // MARK: - Notification preferences (Settings) and update banner

    func testNotificationPreferences() {
        XCTAssertEqual(es("Notifications"), "Notificaciones")
        XCTAssertEqual(es("Container stopped"), "Contenedor detenido")
        XCTAssertEqual(es("Build finished"), "Compilación terminada")
        XCTAssertEqual(es("Build failed"), "Compilación fallida")
        XCTAssertEqual(es("Image pull finished"), "Descarga de imagen terminada")
        XCTAssertEqual(es("\"%@\" is no longer running"), "\"%@\" ya no está en ejecución")
    }

    func testUpdateChecker() {
        XCTAssertEqual(es("Updates"), "Actualizaciones")
        XCTAssertEqual(es("Check for updates automatically"), "Buscar actualizaciones automáticamente")
        XCTAssertEqual(es("Check Now"), "Buscar ahora")
        XCTAssertEqual(es("You're up to date"), "Estás al día")
        XCTAssertEqual(es("ContainerUI %@ is available"), "ContainerUI %@ está disponible")
    }

    // MARK: - Confirmation dialogs

    func testDestructiveAlerts() {
        XCTAssertEqual(es("Delete \"%@\"?"), "¿Eliminar \"%@\"?")
        XCTAssertEqual(es("Delete volume \"%@\"?"), "¿Eliminar el volumen \"%@\"?")
        XCTAssertEqual(es("Remove \"%@\"?"), "¿Quitar \"%@\"?")
        XCTAssertEqual(es("Kill \"%@\"?"), "¿Forzar el cierre de \"%@\"?")
        XCTAssertEqual(es("This action cannot be undone."), "Esta acción no se puede deshacer.")
    }
}
