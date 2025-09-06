# SmartMessage Demos

This repository contains demonstration applications showcasing the capabilities of the [SmartMessage](https://github.com/madbomber/smart_message) gem - a Ruby abstraction for message content protection from backend delivery transport mechanisms.

## Purpose

These demos illustrate real-world usage patterns for building distributed, message-driven applications using SmartMessage's pub/sub architecture. Each demo focuses on different aspects of message-based communication, from simple point-to-point messaging to complex multi-service orchestration.

## Available Demos

### 🏙️ City Services with VSM (`city_services_with_vsm/`)

A comprehensive simulation of a city's emergency management system that demonstrates:

**SmartMessage Features:**
- Redis pub/sub transport for decoupled service communication
- Strongly-typed message schemas with validation
- Location-transparent routing using message headers
- Async message processing with error handling

**Architecture Highlights:**
- **Emergency Services**: 911 dispatch center, police, fire, and health departments
- **Incident Generators**: Citizens, houses, and banks that trigger emergencies
- **Dynamic Service Creation**: AI-powered city council that creates new departments on demand
- **Government Efficiency**: DOGE system for analyzing and consolidating similar services

**VSM Integration:**
- Viable System Model (VSM) framework for AI-enhanced decision making
- 5-system architecture: Identity, Intelligence, Operations, Governance, Coordination
- Template-based department generation from YAML configurations
- Similarity analysis and automated service consolidation

**Key Message Types:**
- `Emergency911Message` - Citizen emergency calls
- `FireDispatchMessage` / `PoliceDispatchMessage` - Service coordination
- `HealthCheckMessage` / `HealthStatusMessage` - System monitoring
- `ServiceRequestMessage` - Dynamic service creation requests
- `DepartmentAnnouncementMessage` - New service notifications

**Running the Demo:**
```bash
cd city_services_with_vsm
bundle install
./start_demo.sh  # Starts all services in iTerm2 tabs
ruby redis_monitor.rb  # Monitor message traffic
```

## SmartMessage Benefits Demonstrated

1. **Transport Independence**: Services communicate through SmartMessage abstraction, not directly with Redis
2. **Message Validation**: Strongly-typed message classes prevent malformed data
3. **Decoupled Architecture**: Services can be started/stopped independently
4. **Scalable Messaging**: Pub/sub pattern supports multiple subscribers
5. **Error Resilience**: Automatic reconnection and error recovery
6. **Observability**: Built-in message logging and statistics

## Requirements

- Ruby 3.x
- Redis server (for message transport)
- Bundler for dependency management

## Contributing

Each demo should:
- Include a comprehensive README.md explaining the scenario
- Provide clear setup and running instructions
- Demonstrate specific SmartMessage features
- Include message flow diagrams where helpful
- Follow consistent code organization patterns

## Future Demos

Planned demonstrations include:
- Microservices orchestration
- IoT device communication
- Chat/messaging applications  
- Distributed task processing
- Real-time collaboration systems

---

For more information about SmartMessage, see the [main repository](https://github.com/madbomber/smart_message).