workspace "PharmaCold Track" "Sistema de control para logística farmacéutica" {

    model {
        #actores
        operador = person "Operador logístico" "Responsable de gestionar envíos y recibir alertas"
        sensor = person "Sensor IoT / Transportista" "Dispositivo o app que envía ubicación y temperatura."

        #Sistemas externos
        emailSystem = softwareSystem "Sistema de correo" "Servidor SMTP externo (Gmail) para envío de alertas." "External System"

        # sistema de software
        pharmaSystem = softwareSystem "PharmaCold Track" "Sistema de gestión de cadena de frío" {
            
            # contenedores
            webApp = container "Aplicación web" "Provee la interfaz de administración y visualización." "Angular" "Web Browser"
            
            backendCore = container "API Backend" "API REST que centraliza la lógica de negocio y reglas de dominio." "Java Spring Boot" {
                
                # componentes - nivell 3
                group "Capa de presentación" {
                    shipmentController = component "Shipment controller" "Expone endpoints para gestión de envíos." "Spring MVC Rest Controller"
                    telemetryController = component "Telemetry controller" "Recibe lecturas de sensores." "Spring MVC Rest Controller"
                }

                group "Capa de aplicación y dominio" {
                    shipmentService = component "Shipment service" "Orquesta la creación y actualización de envíos." "Spring Service"
                    telemetryService = component "Telemetry service" "Procesa entrada de sensores y coordina alertas." "Spring Service"
                    coldChainPolicy = component "Cold chain policy" "Evaluador de reglas de negocio (Invariantes de temperatura)." "Domain Service"
                    notificationService = component "Notification service" "Gestiona la composición y envío de alertas." "Spring Service"
                }

                group "Capa de infraestructura" {
                    shipmentRepo = component "Shipment repository" "Abstracción de persistencia de envíos." "Spring Data JPA"
                    telemetryRepo = component "Telemetry repository" "Abstracción de persistencia de lecturas." "Spring Data JPA"
                }
            }

            database = container "Base de datos" "Almacena datos relacionales y logs de auditoría." "PostgreSQL" "Database"
        }

        # Relaciones del diagram de contexto
        operador -> webApp "Visualiza tableros y gestiona envíos usando"
        sensor -> backendCore "Envía telemetría (POST) usando" "HTTPS/JSON"
        backendCore -> emailSystem "Envía alertas críticas usando" "SMTP/API"
        emailSystem -> operador "Entrega correos de alerta a"

        # Relaciones de contenedores
        webApp -> backendCore "Realiza llamadas API a" "HTTPS/JSON"
        backendCore -> database "Lee y escribe datos en" "JDBC/SQL"

        # Relaciones de componentes
        # Flujo de gestión de envíos
        webApp -> shipmentController "Solicita creación/consulta de envíos"
        shipmentController -> shipmentService "Delega lógica a"
        shipmentService -> shipmentRepo "Persiste estado en"
        
        # Flujo de telemetría y alertas
        sensor -> telemetryController "Envía datos periódicos"
        telemetryController -> telemetryService "Pasa datos crudos a"
        telemetryService -> telemetryRepo "Guarda histórico en"
        telemetryService -> shipmentRepo "Consulta límites del envío en"
        telemetryService -> coldChainPolicy "Solicita evaluación de integridad a"
        
        # Logica de cambio de estado y notificación
        coldChainPolicy -> shipmentRepo "Actualiza estado a COMPROMISED si falla validación"
        telemetryService -> notificationService "Solicita envío de alerta si la política falló"
        notificationService -> emailSystem "Despacha correo vía"
        
        shipmentRepo -> database "SQL"
        telemetryRepo -> database "SQL"
    }

    views {
        systemContext pharmaSystem "Contexto" "Diagrama de contexto del sistema." {
            include *
            autoLayout lr
        }

        container pharmaSystem "Contenedores" "Diagrama de contenedores del sistema." {
            include *
            autoLayout lr
        }

        component backendCore "Componentes" "Diagrama de componentes del núcleo de servicios." {
            include *
            autoLayout tb
        }

        styles {
            element "Person" {
                shape Person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "External System" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
                shape Component
            }
            element "Database" {
                shape Cylinder
            }
            element "Web Browser" {
                shape WebBrowser
            }
        }
    }
}