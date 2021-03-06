Feature: Fail
  In order to diagnose a fault
  As a developer
  I want to get useful information when a feature fails
  
  Scenario: Two features, one fails
    And I am using the simple example app
    When I run cucover -- features/call_foo.feature features/fail.feature
    Then it should fail with:
      """
      Feature: Call Foo
      
        Scenario: Call Foo # features/call_foo.feature:3
          When I call Foo  # features/step_definitions/main_steps.rb:9
      
      Feature: Epic Fail
        In order to make my job look really hard
        As a developer
        I want tests to fail from time to time
      
        Scenario: Do something stupid # features/fail.feature:6
          When I divide by zero       # features/step_definitions/main_steps.rb:13
            divided by 0 (ZeroDivisionError)
            ./features/step_definitions/main_steps.rb:14:in `/'
            ./features/step_definitions/main_steps.rb:14:in `/^I divide by zero$/'
            features/fail.feature:7:in `When I divide by zero'

      Failing Scenarios:
      cucumber features/fail.feature:6 # Scenario: Do something stupid
      
      2 scenarios (1 failed, 1 passed)
      2 steps (1 failed, 1 passed)
      
      """
  
  Scenario: Run failing feature twice
    And I am using the simple example app
    And I have tried to run cucover -- features/fail.feature
    When I run cucover -- features/fail.feature
    Then it should fail with:
    """
    Feature: Epic Fail
      In order to make my job look really hard
      As a developer
      I want tests to fail from time to time
    
      Scenario: Do something stupid # features/fail.feature:6
        When I divide by zero       # features/step_definitions/main_steps.rb:13
          divided by 0 (ZeroDivisionError)
          ./features/step_definitions/main_steps.rb:14:in `/'
          ./features/step_definitions/main_steps.rb:14:in `/^I divide by zero$/'
          features/fail.feature:7:in `When I divide by zero'

    Failing Scenarios:
    cucumber features/fail.feature:6 # Scenario: Do something stupid
    
    1 scenario (1 failed)
    1 step (1 failed)
    
    """
