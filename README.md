# BentOS [![Build Status](https://travis-ci.org/zetavg/BentOS.svg?branch=master)](https://travis-ci.org/zetavg/BentOS) [![Coverage Status](https://coveralls.io/repos/github/zetavg/BentOS/badge.svg?branch=master)](https://coveralls.io/github/zetavg/BentOS?branch=master) [![Maintainability](https://api.codeclimate.com/v1/badges/b40e8bab1e428acb909e/maintainability)](https://codeclimate.com/github/zetavg/BentOS/maintainability)

The **Bento** **O**peration **S**ystem.

## Requirements

* Ruby 2.7
* PostgreSQL 12

## Setup

1. Run `bin/setup`.
2. Edit `.env`.
3. Edit `config/database.yml` and run `bin/rails db:setup` if needed.

## Deploy

### Heroku

This app is deployable to [Heroku](https://www.heroku.com/).

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)
