@fake_test
Feature: Fake test
    Scenario: Fake test
      Then the directory '/tmp' should exist
      When God creates a tmux session named 'test' with a window named 'test'
      Then the tmux session 'test' should exist
      Then the directory '/tmp2' should exist
      Then the tmux session 'test' should exist
