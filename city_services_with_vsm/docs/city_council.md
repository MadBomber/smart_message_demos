# CityCouncil Documentation

## Dynamic City Service Generation System

The CityCouncil program acts as the governing body for the city simulation, capable of dynamically creating and persisting new city service departments as they are requested. It uses the Vector Symbolic Memory (VSM) architecture integrated with SmartMessage for inter-service communication and AI-powered decision making.

## Purpose and Goals

### Why CityCouncil Exists
1. **Dynamic Service Creation**: Automatically generates new city departments when emergency services are needed but don't exist
2. **Service Governance**: Monitors and manages the health of all city departments
3. **Intelligent Response**: Uses AI to understand service requests and determine appropriate department specifications
4. **Self-Healing Architecture**: Automatically restarts failed departments and maintains service availability

### What It Does
- Discovers and catalogs existing city departments (both Ruby and YAML-based)
- Listens for service requests via SmartMessage
- Analyzes requests using AI to determine if new services are needed
- Generates department configurations and launches new services
- Monitors department health and automatically restarts failed services
- Provides a unified governance layer for all city services

### How It Works
- VSM architecture provides five subsystems: Identity, Intelligence, Operations, Governance, and Coordination
- SmartMessage enables publish/subscribe communication between services
- AI (via RubyLLM) analyzes requests and generates department specifications
- Generic department template allows configuration-driven service creation
- Health monitoring ensures service reliability through automatic recovery

## System Architecture

![System Architecture Diagram](city_council_images/architecture_overview.svg)

## Data Flow Diagram

![Data Flow Diagram](city_council_images/service_request_flow.svg)

## Control Flow Diagram

![Control Flow Diagram](city_council_images/control_flow.svg)

## Intelligence Component Flow

![Intelligence Component Flow](city_council_images/diagram_4.svg)

## Operations Component Flow

![Operations Component Flow](city_council_images/operations_flow.svg)

## Message Bus Architecture

![VSM Capsule Components](city_council_images/architecture_overview.svg)

## Department Lifecycle

![Message Flow Sequence](city_council_images/diagram_7.svg)

## Data Structures

### Service Specification
```ruby
{
  name: "animal_control",                    # Department identifier (without _department suffix)
  display_name: "Animal Control",            # Human-readable name
  description: "Handles animal-related emergencies...", # Purpose description
  responsibilities: [                        # List of capabilities
    "Respond to animal attacks",
    "Handle stray animals",
    "Investigate animal bites"
  ],
  message_types: [                          # Messages to publish
    "animal_incident_report",
    "animal_control_dispatch"
  ]
}
```

### Department Health Info
```ruby
{
  pid: 12345,                               # Process ID
  department_file: "animal_control_department.rb", # Executable file
  process_healthy: true,                    # Process exists
  responsive: true,                         # Responds to health checks
  process_failures: 0,                      # Failed process checks
  health_check_failures: 0,                 # Failed health responses
  restart_count: 0,                         # Times restarted
  status: 'running',                        # Current status
  created_at: Time,                         # Creation timestamp
  last_process_check: Time,                 # Last process check
  last_health_request: Time,                # Last health request sent
  last_failure: Time,                       # Last failure time
  last_restart: Time,                       # Last restart time
  awaiting_response: false                  # Waiting for health response
}
```

### Department YAML Configuration
```yaml
department:
  name: animal_control_department
  display_name: Animal Control
  description: Handles animal-related emergencies
  invariants:
  - serve citizens efficiently
  - respond to emergencies promptly
  - maintain operational readiness

capabilities:
- Respond to animal attacks
- Handle stray animals
- Investigate animal bites

message_types:
  subscribes_to:
  - health_check_message
  - emergency_911_message
  publishes:
  - animal_incident_report

routing_rules:
  emergency_911_message:
  - condition: message contains relevant keywords
    keywords: [animal, attack, bite, stray, rabid]
    priority: high
  health_check_message:
  - condition: always
    priority: normal

message_actions:
  emergency_911_message: handle_emergency
  health_check_message: respond_health_check

action_configs:
  handle_emergency:
    response_template: "🚨 ANIMAL_CONTROL: Responding to {{emergency_type}} at {{location}}"
    additional_actions: [log_emergency, notify_dispatch]
    publish_response: true
  respond_health_check:
    response_template: "💗 animal_control_department is operational"
    publish_response: true

logging:
  level: info
  statistics_interval: 300
```

## Key Features

### 1. Dynamic Service Generation
- AI analyzes emergency requests to determine service needs
- Automatically generates department specifications
- Creates YAML configurations from templates
- Launches new departments as separate processes

### 2. VSM Architecture Integration
- **Identity**: Defines CityCouncil's purpose and invariants
- **Intelligence**: AI-powered request analysis and decision making
- **Operations**: Handles actual department creation and management
- **Governance**: Enforces policies and quality standards
- **Coordination**: Manages workflow between components

### 3. Health Monitoring & Recovery
- Monitors department process health every 30 seconds
- Sends health check messages and tracks responses
- Automatically restarts failed departments (up to 3 attempts)
- Removes permanently failed departments from monitoring

### 4. SmartMessage Integration
- Subscribes to service requests from emergency dispatch
- Publishes department announcements for system-wide awareness
- Handles health check/status message exchanges
- Enables asynchronous communication between all city services

### 5. Template-Based Department Creation
- Uses `generic_department.rb` as configurable template
- Generates department-specific YAML configurations
- Extracts keywords from descriptions for message routing
- Creates appropriate message handlers and action configs

## Usage

### Starting CityCouncil
```bash
# Basic mode
ruby city_council.rb

# With interactive CLI
ruby city_council.rb --cli
```

### Environment Variables
```bash
# Set AI provider (default: openai)
export LLM_PROVIDER=ollama
export LLM_MODEL=llama3.2:1b

# Enable debug output
export VSM_DEBUG_STREAM=1
```

### Example Service Request Flow
1. Emergency dispatch sends ServiceRequestMessage: "Need animal control for rabid dog"
2. CityCouncil Intelligence analyzes request
3. Determines "animal_control_department" is needed but doesn't exist
4. Generates service specification with capabilities
5. Operations creates YAML configuration
6. Launches new department process
7. Announces creation to all services
8. Begins health monitoring of new department

## Integration Points

### With Emergency Services
- Receives service requests when departments are missing
- Creates specialized departments based on emergency needs
- Ensures comprehensive emergency response coverage

### With Generic Department Template
- Uses template as base for all new departments
- Passes department name as argument for configuration loading
- Enables rapid deployment of new services

### With VSM Framework
- Leverages VSM's component architecture for separation of concerns
- Uses VSM message bus for internal component communication
- Benefits from VSM's async processing capabilities

### With SmartMessage System
- Integrates with city-wide messaging infrastructure
- Enables real-time communication with all departments
- Supports health monitoring across the entire system

## Benefits

1. **Self-Healing**: Automatically recovers from department failures
2. **Adaptive**: Creates new services as city needs evolve
3. **Intelligent**: Uses AI to understand and fulfill service requests
4. **Observable**: Comprehensive logging and health monitoring
5. **Scalable**: Can manage unlimited number of departments
6. **Maintainable**: Clear separation of concerns through VSM architecture

This documentation provides a comprehensive understanding of the CityCouncil system's architecture, data flows, and operational patterns for dynamic city service generation and management.