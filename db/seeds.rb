require 'rubygems'
require 'mongo'

db = Mongo::Connection.new.db("jagan")
coll = db.collection("applications")

coll.insert({_id: 'myapp9', key: 'mykey9', secret: 'mysecret9'})

