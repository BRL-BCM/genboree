
use admin

db.createRole(
    { "role" : "evalRunner"
    , "privileges" : [ 
            { "resource" : { "anyResource" : true }
            , "actions" : [ "anyAction" ] 
            } ]
    , "roles" : [ ] 
    } )

db.createUser(
    { "user"  : "genboree"
    , "pwd"   : "genboree"
    , "roles" : 
            [ { "role" : "userAdminAnyDatabase", "db" : "admin" }
            , { "role" : "readWriteAnyDatabase", "db" : "admin" }
            , { "role" : "dbAdminAnyDatabase"  , "db" : "admin" }
            , { "role" : "clusterAdmin"        , "db" : "admin" }
            , { "role" : "evalRunner"          , "db" : "admin" } 
            ]
    } )

