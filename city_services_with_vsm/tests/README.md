# City Services Test Suite

This directory contains formal tests for the city services simulation using the **minitest** framework.

## Test Structure

### Core Test Files
- **test_helper.rb** - Common setup, utilities, and test base class
- **run_tests.rb** - Main test runner script
- **Rakefile** - Rake tasks for running tests

### Test Classes  
- **test_department_discovery.rb** - Tests department discovery logic
- **test_messages.rb** - Tests SmartMessage message classes
- **test_service_requests.rb** - Tests service request functionality
- **test_doge_vsm_tools.rb** - Tests DOGE VSM analysis tools
- **test_generic_department.rb** - Tests generic department functionality

### Fixtures
- **fixtures/** - Test data and configuration files

## Running Tests

### All Tests
```bash
# Using the test runner
ruby tests/run_tests.rb

# Using Rake (recommended)
rake test
```

### Individual Test Suites
```bash
rake test:discovery    # Department discovery
rake test:messages     # SmartMessage classes
rake test:requests     # Service requests  
rake test:doge         # DOGE VSM tools
rake test:department   # Generic department
```

### Test Information
```bash
rake info              # Show available tasks and test files
```

## Test Dependencies

### Required
- **minitest** - Core testing framework
- **minitest-reporters** - Enhanced test output
- **smart_message** - SmartMessage library
- **yaml** - Configuration loading

### Optional (tests will skip if not available)
- **vsm** - VSM library (for DOGE tests)
- Department configuration files (for department tests)

## Test Helpers

The `TestHelpers` module provides:
- **create_test_service_request()** - Create test service request messages
- **wait_for_condition()** - Async operation timeouts
- **assert_file_exists()** - File existence assertions
- **assert_directory_exists()** - Directory existence assertions
- **capture_stdout()** - Capture program output

## Base Test Class

All tests inherit from `CityServicesTestCase` which provides:
- Common setup/teardown with timing
- Access to test helpers
- Colored output and progress indicators

## Converted from Informal Tests

This formal test suite was created from these original informal tests:
- `simple_discovery_test.rb` → `test_department_discovery.rb`
- `test_department_creation.rb` → `test_service_requests.rb`
- `test_tools_directly.rb` → `test_doge_vsm_tools.rb`
- `test_water_request.rb` → `test_service_requests.rb`
- `test_department_unit.rb` → `test_generic_department.rb` (refactored)

## Test Categories

### Unit Tests
- Individual component functionality
- Message creation and validation
- Configuration loading

### Integration Tests  
- Service request workflows
- Department discovery
- DOGE analysis pipelines

### System Tests
- End-to-end message flows
- Multi-component interactions

## Adding New Tests

1. Create a new test file: `tests/test_your_feature.rb`
2. Inherit from `CityServicesTestCase`
3. Use the test helpers from `TestHelpers` module
4. Add any new Rake tasks to `Rakefile`

Example:
```ruby
#!/usr/bin/env ruby
require_relative 'test_helper'

class TestYourFeature < CityServicesTestCase  
  def test_something
    assert true, "This should pass"
    puts "   Test completed successfully"
  end
end
```