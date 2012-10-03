# Change Log

## 0.7.0

* Added a new environment variable for all array mappings "#{key}_length" that will hold the length of the array.

## 0.6.3

* Properties with characters outside of [a-zA-Z0-9_] will have those characters converted to _ before being set as environment variables.

## 0.6.2

* Make the --yes option automatically accept defaults (as per it's documentation)

## 0.6.1

* Added a changelog
* Handle an uncommon race condition where the instance has not been created before tags are set
