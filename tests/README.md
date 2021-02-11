## Smoke tests for `discourse-setup`

These are not **real** tests, but do test that `discourse-setup` can produce or modify
the YML file as expected. 

Tests will not run if yml files exist already. If the tests succeed, the container files are deleted.

### `standalone` tests

- run the first time to do an initial creation of `app.yml` and that the values get set as expected.
- run again to change the values

### `two-container` tests

- run with `--two-container` switch to create separate data and web containers
- run again (not requiring the `--two-container` switch) and update values as expected

### `update-old-templates` tests

- updates a very old (Sep 6, 2016) standalone.yml 
- updates a pretty old (Apr 13, 2018) web_only.yml 

The tests won't run if `app.yml` or `web_only.yml` exist.

### `run-all-tests`

Runs all three of the above tests and prints an error if `app.yml` or `web_only.yml` exist.

