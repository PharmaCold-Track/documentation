workspace "PharmaCold Track" "Sistema de control para logística farmacéutica" {

    model {
        # actores
        operador = person "Operador Logístico" "Gestiona envíos y recibe alertas."
        sensor = person "Sensor IoT" "Envía telemetría (ubicación/temperatura)."

        # sistemas externos
        emailSystem = softwareSystem "Sistema de Correo" "Servidor SMTP (SendGrid/Gmail)." "External System"

        # sistema de software
        pharmaSystem = softwareSystem "PharmaCold Track" "Sistema de gestión de cadena de frío." {

            # contenedores
            webApp = container "Web App (SPA)" "Dashboard de monitoreo." "Angular/React" "Web Browser"
            database = container "Base de datos" "Almacena datos relacionales y logs de auditoría." "PostgreSQL" "Database"

            backendCore = container "Backend Core" "API REST con arquitectura hexagonal y CQRS lógico." "Java Spring Boot" {

                #Componentes

                # CAPA DE PRESENTACIÓN (Entrada)
                group "Presentation Layer (Web Adapters)" {
                    shipmentController = component "ShipmentController" "Recibe peticiones HTTP y despacha Commands/Queries." "Spring RestController"
                    telemetryController = component "TelemetryController" "Recibe POSTs de sensores y despacha Commands." "Spring RestController"
                }

                #CAPA DE APLICACIÓN (Orquestación - CQRS)
                group "Application Layer (Command/Query Handlers)" {
                    # Write Side (Comandos)
                    createShipmentHandler = component "CreateShipmentCommandHandler" "Maneja la creación del envío. Coordina con Factory." "Spring Component"
                    registerTelemetryHandler = component "RegisterTelemetryCommandHandler" "Maneja la entrada de datos. Coordina persistencia y validación." "Spring Component"

                    # Read Side (Consultas)
                    getShipmentQueryHandler = component "GetShipmentQueryHandler" "Recupera datos optimizados para lectura." "Spring Component"

                    # Event Side (Reacción)
                    alertEventHandler = component "ColdChainCompromisedHandler" "Escucha el evento de dominio y orquesta la notificación." "Spring EventListener"
                }

                # CAPA DE DOMINIO
                group "Domain Layer" {
                    shipmentAgg = component "Shipment Aggregate" "Entidad raíz que encapsula estado y reglas de cambio." "Java Object"
                    coldChainEvaluator = component "ColdChainEvaluator" "Domain Service. Valida si la temperatura cumple las reglas." "Domain Service"
                    domainEvents = component "DomainEventPublisher" "Mecanismo para publicar eventos (ej. ColdChainCompromised)." "ApplicationEventPublisher"
                }

                # CAPA DE INFRAESTRUCTURA
                group "Infrastructure Layer (Persistence Y Adapters)" {
                    shipmentRepo = component "JpaShipmentRepository" "Implementación de persistencia con Hibernate." "Spring Data JPA"
                    telemetryRepo = component "JpaTelemetryRepository" "Implementación de persistencia de telemetría." "Spring Data JPA"
                    emailAdapter = component "EmailNotificationAdapter" "Implementación del puerto de notificaciones." "JavaMailSender"
                }
            }
        }

        # RELACIONES DEL CONTEXTO
        operador -> pharmaSystem "Usa para gestionar flota"
        sensor -> pharmaSystem "Envía datos a"
        pharmaSystem -> emailSystem "Envía alertas críticas a través de"
        emailSystem -> operador "Entrega correos a"

        # RELACIONES DE CONTENEDORES
        operador -> webApp "Visita dashboard en"
        webApp -> backendCore "API Calls (JSON/HTTPS)"
        sensor -> backendCore "API Calls (JSON/HTTPS)"
        backendCore -> database "Lee/Escribe (JDBC)"
        backendCore -> emailSystem "Envía correos (SMTP)"

        # RELACIONES DE COMPONENTES

        # Flujo de lLectura (Query)
        webApp -> shipmentController "GET /shipments/{id}"
        shipmentController -> getShipmentQueryHandler "Ejecuta GetShipmentByIdQuery"
        getShipmentQueryHandler -> shipmentRepo "Lee proyección"
        shipmentRepo -> database "Select SQL"

        # flujo de escritura (Command)
        webApp -> shipmentController "POST /shipments"
        shipmentController -> createShipmentHandler "Despacha CreateShipmentCommand"
        createShipmentHandler -> shipmentAgg "Invoca Factory"
        createShipmentHandler -> shipmentRepo "Guarda estado"

        #flujo crítico (Command)
        sensor -> telemetryController "POST /telemetry"
        telemetryController -> registerTelemetryHandler "Despacha RegisterTelemetryCommand"

        # Orquestación del Handler
        registerTelemetryHandler -> telemetryRepo "Persiste lectura inicial"
        registerTelemetryHandler -> shipmentRepo "Busca Shipment por UUID"
        registerTelemetryHandler -> coldChainEvaluator "Invoca inspect(shipment, reading)"

        # Lógica del dominio y evento
        coldChainEvaluator -> domainEvents "Publica ColdChainCompromisedEvent (si falla)"

        # Reacción síncrona
        domainEvents -> alertEventHandler "Dispara listener"
        alertEventHandler -> shipmentRepo "Actualiza estado a COMPROMISED"
        alertEventHandler -> emailAdapter "Invoca envío de alerta"
        emailAdapter -> emailSystem "Envía SMTP"

        # Conexiones BDD componentes
        shipmentRepo -> database "Insert/Update"
        telemetryRepo -> database "Insert"
    }

    views {
        # Vista Nivel 1
        systemContext pharmaSystem "Contexto" "Diagrama de contexto del sistema." {
            include *
            autoLayout lr
        }

        # Vista Nivel 2
        container pharmaSystem "Contenedores" "Diagrama de contenedores del sistema." {
            include *
            autoLayout lr
        }

        # Vista Nivel 3
        component backendCore "Componentes_CQRS" "Diagrama de componentes detallando CQRS y separación de capas." {
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