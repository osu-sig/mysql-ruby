#!/usr/bin/env ruby
`flay */*.rb > flay_results.txt`
if `cat flay_results.txt | grep IDENTICAL`.length > 0
  puts `cat flay_results.txt`
  exit 1
end