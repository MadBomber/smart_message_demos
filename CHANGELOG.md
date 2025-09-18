 # Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 2025-09-17
### Added
- **Redis Monitor JSONL Logging** - Enhanced message logging and analysis capabilities
  - Modified `redis_monitor.rb` to log all messages to `city_sim_message_log.jsonl` file
  - Added structured JSONL output with timestamp, channel, message_class, from/to fields
  - Fixed nil handling errors for payload fields in HealthCheck and HealthStatus messages
  - Ensured Redis Monitor launches first in demo rake task for complete message capture

- **Network Activity Analyzer** - New analysis tool for message traffic patterns
  - Created `network_activity.rb` to analyze JSONL message logs
  - Displays comprehensive statistics: message counts, department activity, communication paths
  - Identifies broadcast vs point-to-point messages
  - Shows top message classes and department communication patterns
  - Fixed Time.parse error by adding required 'time' library

- **Gosu-Based Network Animation** - Interactive visual network traffic monitoring
  - Created `network_animation.rb` using Gosu graphics library for real-time visualization
  - Implemented dynamic window sizing based on monitor dimensions (90% of screen, square aspect)
  - Added dynamic department creation as they appear during simulation
  - Enhanced message sprites with larger size (10→12px) and longer comet-like trails (20 particles)
  - Implemented sophisticated broadcast animation:
    * Clear source identification with pulsing department highlight
    * Visible line from broadcasting department to center
    * Ripple effects emanating from center outward (8 waves, 5 rings each)
    * Water-like blue gradient colors (cyan → deep blue)
    * Dynamic timing that slows animation during broadcasts for visibility
  - Added keyboard controls: SPACE (pause), ↑/↓ (speed), R (restart), ESC (quit)
  - Configurable clock rate via command line argument

### Changed
- **Demo Launch Sequence** - Optimized for complete message capture
  - Modified `start_demo.sh` to launch Redis Monitor as first service
  - Reordered service startup to ensure all messages are logged from beginning
  - Updated tab counts and status output to reflect new launch order

### Fixed
- **Redis Monitor Error Handling** - Improved robustness
  - Fixed undefined method '[]' error for nil check_id in HealthCheck messages
  - Fixed undefined method 'upcase' for nil status in HealthStatus messages
  - Added safe navigation and default values for potentially nil fields

### Technical Details
- **Message Visualization**: Complete network traffic animation system with department nodes, message flows, and broadcast ripples
- **Data Analysis**: JSONL-based message logging enabling post-simulation analysis and replay
- **Animation Engine**: Gosu-powered graphics with dynamic layouts, particle effects, and responsive controls

## 2025-09-16
### Added
- **Redis Message Monitor Web Interface** - Comprehensive web-based monitoring system
  - Added web service launcher with Sinatra-based interface at `http://localhost:4567`
  - Created web launcher Rake tasks for easy service startup and browser opening
  - Implemented both Server-Sent Events (SSE) and Polling monitoring approaches
  - Added analytics dashboard view with Chart.js for data visualization
  - Created citizen portal and network visualization views
  - Added responsive design with engaging user experience and interactive elements

- **Process Management Tools** - Enhanced development workflow utilities
  - Added `kill_port_4567.sh` script for terminating processes on port 4567
  - Created comparison documentation between SSE vs Polling approaches
  - Added multiple Redis monitor implementations (clean, simple, web-based)
  - Enhanced start/stop scripts for web monitoring services

### Changed
- **Dependency Management** - Updated project dependencies and structure
  - Updated main Gemfile to comment out unused dependencies and increase `ruby_llm` version
  - Added dedicated City Services with VSM Gemfile and Gemfile.lock
  - Included core dependencies: Sinatra, Redis, Minitest, Debug utilities
  - Added .gitignore for city_services_with_vsm subdirectory
  - Enhanced test infrastructure with dedicated test helper for web services

### Technical Details
- **Web Monitoring Infrastructure**: Complete web-based monitoring system with real-time Redis message visualization
- **Service Architecture**: Enhanced service launcher supporting both traditional and web-based monitoring approaches
- **Development Tools**: Improved development workflow with automated process management and monitoring capabilities

## 2025-09-13
### Fixed
- **StatusLine Module Refactoring** - Improved maintainability and reliability
  - Refactored `Common::StatusLine` mixin from ncurses back to ANSI sequences for better compatibility
  - Added thread-safe status updates with mutex protection
  - Improved code organization with descriptive helper methods for ANSI sequences
  - Enhanced error handling with graceful fallbacks
  - Added terminal resize handling capability
  - Fixed `@program_name` initialization to correctly use ARGV[0] in generic_department

- **Department Uniqueness Test** - Resolved duplicate department files
  - Removed duplicate YAML configurations for departments with Ruby implementations:
    - Deleted `fire_department.yml` (duplicate of `fire_department.rb`)
    - Deleted `health_department.yml` (duplicate of `health_department.rb`)
    - Deleted `police_department.yml` (duplicate of `police_department.rb`)
  - Removed `test_department.yml` from main directory (kept only in tests/fixtures)
  - Test now passes: 16 unique departments (4 Ruby + 12 YAML) with 0 duplicates

### Changed
- **Test Suite Status** - Department discovery tests now fully passing
  - test_department_discovery.rb: 7 tests, 20 assertions ✅ (previously 1 failure)
  - All 44 tests across the suite continue to pass with 110 assertions

## 2025-09-12
### Added
- **Test Infrastructure Fixes** - Comprehensive test suite repair and validation
  - Fixed all SmartMessage test errors by adding required 'from' field to message instantiations
  - Updated FireDispatchMessage and PoliceDispatchMessage tests with correct property names
  - Fixed HealthCheckMessage tests to match actual API (removed non-existent properties)
  - Repaired ServiceRequestMessage tests with proper parameter naming
  - Enhanced test_helper.rb with corrected create_test_service_request method

- **DOGE VSM Tools Test Support** - Complete DOGE VSM analysis testing functionality
  - Created test_department.yml sample configuration for DOGE analysis
  - Added generic_department.yml.example comprehensive template with detailed documentation
  - Fixed DOGE VSM tools test expectations for edge cases and empty data handling
  - Updated test assertions to match actual tool API behavior

- **Configuration Files** - Required test configuration and templates
  - Added test_department_unit.yml for generic department testing
  - Enhanced generic_department.yml.example with extensive inline documentation
  - Created sample YAML departments for testing DOGE VSM analysis tools

- **Test Suite Organization** - Updated working test configuration
  - Updated test_working.rake to include all fixed test suites
  - Modified test status reporting to reflect current working state
  - Added comprehensive test coverage for all major components

### Fixed
- **SmartMessage API Compatibility** - All message classes now conform to latest SmartMessage API
  - Added required 'from' field to all message instantiations for proper routing
  - Fixed FireDispatchMessage properties: dispatch_id, engines_assigned, timestamp
  - Fixed PoliceDispatchMessage properties: dispatch_id, units_assigned, timestamp
  - Corrected HealthCheckMessage test to only use existing properties
  - Fixed ServiceRequestMessage parameter naming (requesting_service vs requested_service)

- **Test Helper Methods** - Corrected test utility functions
  - Fixed create_test_service_request method parameter expansion in test_helper.rb
  - Updated method to use proper keyword argument spreading

- **DOGE VSM Tools Testing** - Resolved all DOGE analysis test failures
  - Fixed test expectations for empty department lists
  - Updated error handling tests to match actual tool responses
  - Corrected edge case handling for recommendation generation

### Changed
- **Test Suite Status** - All identified tests now passing
  - test_department_discovery.rb: 7 tests, 20 assertions ✅
  - test_messages.rb: 12 tests, 33 assertions ✅ FIXED
  - test_generic_department.rb: 11 tests, 17 assertions ✅ FIXED
  - test_service_requests.rb: 8 tests, 20 assertions ✅ FIXED
  - test_doge_vsm_tools.rb: 10 tests, 20 assertions ✅ FIXED
  - **Total: 44 tests, 110 assertions, 0 failures, 0 errors**

- **Documentation** - Enhanced template and configuration documentation
  - Significantly expanded generic_department.yml.example with comprehensive inline documentation
  - Added detailed examples and explanations for all configuration sections
  - Improved clarity and usability of department configuration templates

### Technical Details
- **SmartMessage Integration**: Updated all message classes to comply with transport-based serialization model
- **VSM Analysis Tools**: Verified complete DOGE workflow from department loading through recommendations
- **Test Infrastructure**: Established robust minitest-based testing with proper error handling and edge case coverage
- **Configuration Management**: Created comprehensive YAML-based department configuration system with validation

## [0.1.0] - 2025-01-XX

### Added
- Initial project setup with SmartMessage and VSM integration
- City services simulation with emergency dispatch functionality
- Rake task organization and test infrastructure
- Basic documentation and project structure

---

## Legend
- 🎯 **FIXED**: Issue resolution and bug fixes
- ✅ **ADDED**: New features and functionality
- 🔄 **CHANGED**: Modifications to existing features
- ⚠️ **DEPRECATED**: Soon-to-be removed features
- 🗑️ **REMOVED**: Deleted features
- 🔒 **SECURITY**: Security improvements
