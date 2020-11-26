# CrispTable RB

CrispTable allows developers to quickly build data-centric, flexible tables. This is the Ruby on Rails backend, a [frontend](https://github.com/gojilabs/crisp-table-js) is also required. CrispTable allows for free-text search, AND searching across multiple columns, column-type searches (e.g. integer and date range searches, string wildcard search) sorting, pagination (with user-configurable page lengths), CSV export, column showing/hiding, and is very fast. It achieves this speed by reducing the amount of Ruby objects necessary when returning large numbers of results, by requiring the developer to do more complex querying in SQL directly, but this is rarely necessary. CrispTable by default uses ActiveRecord querying, executes the query as raw SQL, and then returns the results arrays directly to the frontend, skipping most of the Ruby deserialization/serialization work that hurts performance with hundreds or thousands of records.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'crisp-table', github: 'gojilabs/crisp-table-rb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install crisp-table

After the gem has been installed, integrate it into your Rails project by:

1. Adding `include CrispTable::Controller` in each controller (or a base controller) you want to render tables from.
2. Installing the [frontend](https://github.com/gojilabs/crisp-table-js)
3. Adding a pack to `app/javascript/packs` called `crisp-table.js` with the following content:
```javascript
var crispTableContext = require.context('crisp-table', true)
var ReactRailsUJS = require('react_ujs')
ReactRailsUJS.useContext(crispTableContext)
```
4. Adding `javascript_pack_tag 'crisp-table'` to your layout
5. Creating a directory `tables` under `app`

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/crisp-table. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

Copyright © [Goji Labs](https://www.gojilabs.com) 2020.
