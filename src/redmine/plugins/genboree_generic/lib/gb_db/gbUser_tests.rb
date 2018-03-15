
# Manual unit tests
# - Suitable for running in Rails console, but note that you won't have User.current
#   to test automatical args and such.

# ----------------------------------------------------------------
# Mock a Rack env hash since assumed and needed by constructors
# - (always available in real conditions; via 'env' in Controllers for example)
rackEnv = { 'action_dispatch.request_id' => '534890612862474',  'async.callback' => Proc.new { |*args| $stderr.puts "\n\nMOCK Rack 'async.callback'. Args: #{args.inspect}" }, :currRmUser => User.current }

# ----------------------------------------------------------------
# Blocking tests

  gah = GbApi::GbAuthHelper.new( rackEnv )
  # gu = gah.gbUser() # Only works when Redmine running and a user is logged in [operates via rackEnv[:currRmUser].login]
  # OR
  gu = GbDb::GbUser.byLogin(rackEnv, 'andrewj', { :dbHost => gah.gbAuthHost } )
  # OR
  gu = GbDb::GbUser.byLogin(rackEnv, 'andrewj' )
  # OR
  gu = nil ; GbDb::GbUser.byLogin(rackEnv, 'andrewj' ) { |xx| gu = xx[:obj] }
  gu

  # Similarly by userId
  # - no exist
  gu = nil ; GbDb::GbUser.byUserId(rackEnv, 200_123 ) { |xx| gu = xx[:obj] }
  gu
  # - exist
  gu = nil ; GbDb::GbUser.byUserId(rackEnv, 2 ) { |xx| gu = xx[:obj] }
  gu

  # Similarly by email (will be OLDEST one with this email)
  gu = nil ; GbDb::GbUser.byEmail(rackEnv, 'andrewj@bcm.edu' ) { |xx| gu = xx[:obj] }
  gu

  gur = nil ; gu.gbUserRec() { |xx| gur = ( xx[:rows] ? xx[:rows].first : xx[:err] ) }
  gur
  gur.object_id
  # use in-memory record (same object id)
  gur = nil ; gu.gbUserRec() { |xx| gur = ( xx[:rows] ? xx[:rows].first : xx[:err] ) }
  gur.object_id
  # force reload (new object id)
  gu.reload() { |xx| puts "reload callback arg: #{xx.inspect}"} # force reload (new object id)
  gur = nil ; gu.gbUserRec() { |xx| gur = ( xx[:rows] ? xx[:rows].first : xx[:err] ) }
  gur
  gur.object_id

  gu.userId
  gu.login
  gu.email
  gu.lastName

  # >>>> Blocking approaches still work

  # - Use userId from gu
  gu.allExternalHostInfoByGbUserId( )
  # - Supply one
  gu.allExternalHostInfoByGbUserId( 2 )
  # - With a code block (even though reactor not running; uses generic)
  gu.allExternalHostInfoByGbUserId( 2 ) { |xx| puts "REC:\n\n#{JSON.pretty_generate(xx)}\n\n" }

  # - Low-Level Tests (not to be called by dev code!)
  rr1 = gu.userRecsByGbLogin( 'andrewj' )
  rr2 = gu.userRecByGbLogin( 'andrewj' )
  rr3 = gu.selectByFieldWithMultipleValues('genboreeuser', 'name', ['andrewj'] ) { |rs| $stderr.puts "3. callback arg: #{rs.inspect}" }
  rr3_1 = gu.selectByFieldWithMultipleValues('genboreeuser', 'name', ['andrewj'], { :desiredFields => ['firstName', 'lastName', 'email'] } ) { |rs| $stderr.puts "3.1. callback arg: #{rs.inspect}" }
  rr3_2 = gu.selectByFieldWithMultipleValues('genboreeuser', 'email', ['andrewj@bcm.edu'] ) { |rs| $stderr.puts "3.2. rs count: #{rs[:rows].size}" }
  rr3_3 = gu.selectByFieldWithMultipleValues('genboreeuser', 'email', ['andrewj@bcm.edu'], { :distinct => true } ) { |rs| $stderr.puts "3.3. rs count: #{rs[:rows].size}" }
  rr3_4 = gu.selectByFieldWithMultipleValues('genboreeuser', 'email', ['andrewj@bcm.edu'], { :desiredFields => ['firstName', 'lastName', 'email'], :distinct => true } ) { |rs| $stderr.puts "3.4. rs count: #{rs[:rows].size}" }
  rr4 = gu.selectByFieldValueMap('genboreeuser', { 'name' => 'andrewj' }, :or ) { |rs| $stderr.puts "4. callback arg: #{rs.inspect}" }
  rr4_1 = gu.selectByFieldValueMap('genboreeuser', { 'email' => 'andrewj@bcm.edu' }, :or, opts = { :desiredFields => nil, :distinct => false } ) { |rs| $stderr.puts "4.1. callback arg: #{rs.inspect}" }

  rr4_2 = gu.selectByFieldValueMap('genboreeuser', { 'email' => 'andrewj@bcm.edu', 'firstName' => 'A_R' }, :and, opts = { :desiredFields => nil, :distinct => false } ) { |rs| $stderr.puts "4.2. callback arg: #{rs.inspect}" }

  # >>>>> Create new record


  # - Can create brand new, with own-group creation disabled (bad idea)
  seed = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '', { :createOwnGroup => false} ) { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
  }
  gu
  gu.userId

  # - *TRY* to create same again, but with login that differs only by case from existing one (not allowed)
  gu = nil ; GbDb::GbUser.create(rackEnv, "ARJ-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '', { :createOwnGroup => false} ) { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
  }

  # - Can create brand new
  seed = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
  }
  gu
  gu.userId

  # - Obvious collision (create from same, again)...should be an :err complaining about login
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
  }
  gu

  # - Less obvious collision--different username, but email already in use!
  seed2 = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed2}", "#{seed}@nowhere.net", "xx#{seed2}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
  }
  gu

  # >>>>> Can we make changes?

  # - Create a brand new one to play with
  seed = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
  }
  gu
  gu.userId

  # - Basic thing using convenience method: institution
  gu.institution
  gu.institutionUpdate(gu.login, "CHANGED-#{gu.institution}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM institutual UPDATE: #{rs.inspect}"
  }
  gu.institution

  # - Since login is not case sensitive, any case can be used to make changes
  gu.login
  gu.login.upcase
  gu.institution
  gu.institutionUpdate(gu.login.upcase, "CHANGED-VIA-UPCASE-#{gu.institution}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM institutual UPDATE: #{rs.inspect}"
  }
  gu.institution

  # - Basic thing using convenience method: password
  gu.password
  gu.passwordUpdate( gu.login, "CHANGED-#{gu.password}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM password UPDATE: #{rs.inspect}"
  }
  gu.password

  # - Basic thing using GENERIC method: lastName
  gu.lastName
  gu.fieldUpdate(gu.login, 'lastName', "CHANGED-#{gu.lastName}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM lastName UPDATE: #{rs.inspect}"
  }
  gu.lastName

  # - How about sync'ing with Redmine?
  # . First make sure we have a Redmine shadowRecord
  gu.createRedmineEntity { |result|
    puts "Result of getting redmine entity object for newly created Genboree user:\n\n#{result.inspect}\n\n"
  }
  User.find_by_login( gu.login ).lastname
  # . Now change last name in genboree, but tell to sync with redmine
  gu.lastName
  gu.fieldUpdate(gu.login, 'lastName', "SYNC2RM-#{gu.lastName}", { :syncToRedmine => true }) { |rs|
    $stderr.puts ">>>> RESULT SET FROM lastName UPDATE: #{rs.inspect}"
  }
  gu.lastName
  User.find_by_login( gu.login ).lastname

  # - FORBIDDEN thing using GENERIC method: userId and login should give error
  gu.login
  gu.fieldUpdate(gu.login, 'name', "CHANGED-#{gu.login}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM login UPDATE: #{rs.inspect}"
  }
  gu.login

  gu.userId
  gu.fieldUpdate(gu.login, 'userId', "CHANGED-#{gu.userId}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM userId UPDATE: #{rs.inspect}"
  }
  gu.userId

  # - Can change email but ONLY to email that not already taken by someone (not even by current record
  #   since that wouldn't be an actual change anway)
  gu.email
  gu.fieldUpdate(gu.login, 'email', "CHANGED-#{gu.email}") { |rs|
    $stderr.puts ">>>> RESULT SET FROM userId UPDATE: #{rs.inspect}"
  }
  gu.email
  # (next should fail)
  gu.email
  gu.fieldUpdate(gu.login, 'email', "andrewj@bcm.edu") { |rs|
    $stderr.puts ">>>> RESULT SET FROM userId UPDATE: #{rs.inspect}"
  }
  gu.email

  # >>>>> Can we use upsert() to update various details of a user all at once?

  # - upsert various new info--includiing email to one that we know is NOT in use--we'll change all of them except lastName, say.
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }
  gu.upsert( gu.login, "USR_UPDATE-#{gu.email}", "USR_UPDATE-#{gu.password}", "USR_UPDATE-#{gu.institution}", "USR_UPDATE-#{gu.firstName}", gu.lastName, "USR_UPDATE-#{gu.phone}" ) { |rs|
    $stderr.puts ">>>> RESULT SET FROM multi-field UPDATE: #{rs.inspect}"
  }
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }

  # - This should also work because although email is unchanged (and thus IN USE), it is in use BY THIS RECORD. Which is ok.
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }
  gu.upsert( gu.login, gu.email, "USR_UPDATE2-#{gu.password}", "USR_UPDATE2-#{gu.institution}", "USR_UPDATE2-#{gu.firstName}", gu.lastName, "USR_UPDATE2-#{gu.phone}" ) { |rs|
    $stderr.puts ">>>> RESULT SET FROM multi-field UPDATE: #{rs.inspect}"
  }
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }

  # - How about sync'ing with Redmine?
  # . First make sure we have a Redmine shadowRecord
  gu.createRedmineEntity { |result|
    puts "Result of getting redmine entity object for newly created Genboree user:\n\n#{result.inspect}\n\n"
  }
  User.find_by_login( gu.login ).inspect
  # . Now change last name in genboree, but tell to sync with redmine
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }
  gu.upsert( gu.login, gu.email, "SYNC2RM-#{gu.password}", "SYNC2RM-#{gu.institution}", "SYNC2RM-#{gu.firstName}", gu.lastName, "SYNC2RM-#{gu.phone}", { :syncToRedmine => true } ) { |rs|
    $stderr.puts ">>>> RESULT SET FROM multi-field UPDATE: #{rs.inspect}"
  }
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }
  User.find_by_login( gu.login ).inspect

  # - This should fail because email we're chaning to is in use by a different record.
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }
  gu.upsert( gu.login, 'andrewj@bcm.edu', "USR_UPDATE3-#{gu.password}", "USR_UPDATE3-#{gu.institution}", "USR_UPDATE3-#{gu.firstName}", gu.lastName, "USR_UPDATE3-#{gu.phone}" ) { |rs|
    $stderr.puts ">>>> RESULT SET FROM multi-field UPDATE: #{rs.inspect}"
  }
  gu.gbUserRec() { |xx| $stderr.puts xx.inspect }

  # >> Check un-rescued powerful Exception in dev callback. Is it caught & handled, thus protecting? <<

  # - Should be noticed/logged with a trace, but then the Rack callback should be called directly with a custom triple
  #   that contains an error JSON.
  gu.gbUserRec() { |xx| raise SyntaxError, "syntax!" }

  # - Should create the new record, but then dev exception (no such method no_such_method for nil) should be
  #     noticed/logged, and then Rack callback should be called directly with code 500 via custom triple.
  #     Verify manually that record was created.
  seed = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    nil.no_such_method
  }

  # - In this more likely/natural failure by the dev, they just waltz forward assuming that result[:obj] is available,
  #   whereas they SHOULD have checked for it first (and perhaps :err, where there is indeed information). This results in
  #   un-rescued exception from the dev callback code...which is caught and logged and results in direct response
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    # Dev assumes rs[:obj] is present and fails to check first
    rs[:obj].userId * 7
  }

  # - Here is a completely deranged situation where the dev didn't even provide a callback, which is an ArgumentError
  #   for most of the library methods. But even here, it will attempt to catch the problem--which is not in dev's callback
  #   but rather THEY GAVE NO CALLBACK--and attempt to reply to the client directly, as in cases above.
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '')

# ----------------------------------------------------------------
# Non-blocking tests

EM.run {

  gah = GbApi::GbAuthHelper.new( rackEnv )
  $stderr.puts gah.inspect

  GbDb::GbUser.byLogin(rackEnv, 'andrewj' ) { |xx| gu = xx[:obj] ; $stderr.puts gu.inspect }

  # Similarly by userId
  # - no exist
  GbDb::GbUser.byUserId(rackEnv, 200_123 ) { |xx| gu = xx[:obj] ;  $stderr.puts "Actual userId: #{gu.userId.inspect}" ; $stderr.puts gu.inspect }
  # - exist
  GbDb::GbUser.byUserId(rackEnv, 2 ) { |xx| gu = xx[:obj] ; $stderr.puts gu.inspect }

  # Similarly by email (will be OLDEST one with this email)
  GbDb::GbUser.byEmail(rackEnv, 'andrewj@bcm.edu' ) { |xx|
    gu = xx[:obj]
    $stderr.puts gu.inspect
    gu.gbUserRec() { |xx|
      gur = ( xx[:rows] ? xx[:rows].first : xx[:err] )
      $stderr.puts gur.inspect
      $stderr.puts gur.object_id
    }
    # use in-memory record (same object id)
    gu.gbUserRec() { |xx|
      gur = ( xx[:rows] ? xx[:rows].first : xx[:err] )
      $stderr.puts gur.object_id
      # force reload (new object id)
      gu.reload() { |rs| # force reload (new object id)
        $stderr.puts "RELOAD CALLBACK ARG: #{rs.inspect}"
        gu.gbUserRec() { |xx|
          gur = ( xx[:rows] ? xx[:rows].first : xx[:err] )
          $stderr.puts gur.inspect
          $stderr.puts gur.object_id
          $stderr.puts gu.userId
          $stderr.puts gu.login
          $stderr.puts gu.email
          $stderr.puts gu.lastName

          # >>>> Blocking approaches still work

          # - Use userId from gu
          $stderr.puts "No arg host info: #{gu.allExternalHostInfoByGbUserId().inspect}"
          # - Supply one
          $stderr.puts "Arg host info: #{gu.allExternalHostInfoByGbUserId( 2 ).inspect}"

          # - With a code block (even though reactor not running; uses generic)
          gu.allExternalHostInfoByGbUserId( 2 ) { |xx| puts "EM callbackREC:\n\n#{JSON.pretty_generate(xx)}\n\n" }

          # - Low-Level Tests (NOT to be called by dev code! for internal library implementation)
          # . These are done immediately (sync) because no callback for deferred execution:
          $stderr.puts "1. #{rr1 = gu.userRecsByGbLogin( 'andrewj' ).inspect} "
          $stderr.puts "2. #{rr2 = gu.userRecByGbLogin( 'andrewj' ).inspect } "
          # . These are done later, async (but probably in order)
          gu.selectByFieldWithMultipleValues('genboreeuser', 'name', ['andrewj'] ) { |rs| $stderr.puts "3. [select by login] callback arg: #{rs.inspect}" }
          gu.selectByFieldWithMultipleValues('genboreeuser', 'name', ['andrewj'], { :desiredFields => ['firstName', 'lastName', 'email'] } ) { |rs| $stderr.puts "3.1. [same, but only 3 output cols] callback arg: #{rs.inspect}" }
          gu.selectByFieldWithMultipleValues('genboreeuser', 'email', ['andrewj@bcm.edu'] ) { |rs| $stderr.puts "3.2. [count rec w/email] rs count: #{rs[:rows].size}" }
          gu.selectByFieldWithMultipleValues('genboreeuser', 'email', ['andrewj@bcm.edu'], { :distinct => true } ) { |rs| $stderr.puts "3.3. [count distinct recs w/email (all output rows are distinct)] rs count: #{rs[:rows].size}" }
          gu.selectByFieldWithMultipleValues('genboreeuser', 'email', ['andrewj@bcm.edu'], { :desiredFields => ['firstName', 'lastName', 'email'], :distinct => true } ) { |rs| $stderr.puts "3.4. [count distinct recs w/email (since only 3 output cols, some output rows are duplicates)] rs count: #{rs[:rows].size}" }
          gu.selectByFieldValueMap('genboreeuser', { 'name' => 'andrewj' }, :or ) { |rs| $stderr.puts "4. [select by login via col2val] callback arg: #{rs.inspect}" }
          gu.selectByFieldValueMap('genboreeuser', { 'email' => 'andrewj@bcm.edu' }, :or, opts = { :desiredFields => nil, :distinct => false } ) { |rs| $stderr.puts "4.1. [select by email via col2val] callback arg: #{rs.inspect}" }
          gu.selectByFieldValueMap('genboreeuser', { 'email' => 'andrewj@bcm.edu', 'firstName' => 'A_R' }, :and, opts = { :desiredFields => nil, :distinct => false } ) { |rs| $stderr.puts "4.2. [select by email & firstName via col2val + 'AND'] callback arg: #{rs.inspect}" }
        }
      }
    }
  }
} # EM.run

EM.run {
  # >>>>> Create new record

  # - Can create brand new
  seed = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> A. RESULT SET FROM CREATE: #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
    $stderr.puts "       - gu: #{gu.inspect}"

    # . Fail because login already exists (differs only by case)
    gu = nil ; GbDb::GbUser.create(rackEnv, "ARJ-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
      $stderr.puts ">>>> A.5. RESULT SET FROM CREATE: #{rs.inspect}"
      gu = (rs[:obj] or rs[:err])
      $stderr.puts "       - gu: #{gu.inspect}"

      # - Obvious collision (create from same, again)...should be an :err complaining about login
      gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
        $stderr.puts ">>>> B. RESULT SET FROM CREATE (login collision): #{rs.inspect}"
        gu = (rs[:obj] or rs[:err])
        $stderr.puts "       - gu: #{gu.inspect}"
      }

      # - Less obvious collision--different username, but email already in use!
      seed2 = "#{$$}-#{rand(1000)}"
      gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed2}", "#{seed}@nowhere.net", "xx#{seed2}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
        $stderr.puts ">>>> C. RESULT SET FROM CREATE (email collision): #{rs.inspect}"
        gu = (rs[:obj] or rs[:err])
        $stderr.puts "       - gu: #{gu.inspect}"
      }
    }
  }
} # EM.run

EM.run {
  # >>>>> Can we make changes?

  # - Create a brand new one to play with
  seed = "#{$$}-#{rand(1000)}"
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts ">>>> D. RESULT SET FROM CREATE (brand new, to change): #{rs.inspect}"
    gu = (rs[:obj] or rs[:err])
    $stderr.puts "       - gu: #{gu.inspect}"

    # Do illustrative changes WITHIN callback of create so we KNOW we have the record (remember, async)
    # - Basic thing using convenience method: institution

    $stderr.puts "       - gu.institution BEFORE change: #{gu.institution.inspect}"
    gu.institutionUpdate(gu.login, "CHANGED-#{gu.institution}") { |rs|
      $stderr.puts ">>>> D.1. RESULT SET FROM institutual UPDATE: #{rs.inspect}"
      $stderr.puts "       - same gu object's institution AFTER change: #{gu.institution.inspect}"

      # Could have done this in async to changing instititute or lastName etc, since all same gu object and no dependencies
      # - Basic thing using convenience method: passwordv
      $stderr.puts "       - password BEFORE change: #{gu.password.inspect}"
      gu.passwordUpdate( gu.login, "CHANGED-#{gu.password}") { |rs|
        $stderr.puts ">>>> D.2. RESULT SET FROM password UPDATE: #{rs.inspect}"
        $stderr.puts "       - same gu object's password AFTER change: #{gu.password.inspect}"
      }

      # Here, this is technically async with passwordUpdate above...no guarantee which will happen first
      # (in fact the stderr that happens next will execute BEFORE the passwordUpdate callback...*obviously*)
      # - Basic thing using GENERIC method: lastName
      $stderr.puts "       - lastName BEFORE change: #{gu.password.inspect}"
      gu.fieldUpdate(gu.login, 'lastName', "CHANGED-#{gu.lastName}") { |rs|
        $stderr.puts ">>>> D.3. RESULT SET FROM lastName UPDATE: #{rs.inspect}"
        $stderr.puts "       - same gu object's lastName AFTER change: #{gu.lastName.inspect}"

        # - Now try a FORBIDDEN thing using GENERIC method: userId and login should give error
        # . change login [attempt] first
        begin
          $stderr.puts "       - login BEFORE change: #{gu.login.inspect}"
          gu.fieldUpdate(gu.login, 'name', "CHANGED-#{gu.login}") { |rs|
            # WON'T REACH THIS BECAUSE Exception immediately thrown
            $stderr.puts ">>>> D.4. RESULT SET FROM login (forbidden) UPDATE: #{rs.inspect}"
          }
        rescue => err
          $stderr.puts "Method failed IMMEDIATELY (raised Exception) ! #{err.class} => #{err.message}"
        end

        # . change userId [attempt]
        begin
          $stderr.puts "       - userId BEFORE change: #{gu.userId.inspect}"
          gu.fieldUpdate(gu.login, 'userId', "CHANGED-#{gu.userId}") { |rs|
            # WON'T REACH THIS BECAUSE Exception immediately thrown
            $stderr.puts ">>>> D.5. RESULT SET FROM userId (forbidden) UPDATE: #{rs.inspect}"
          }
        rescue => err
          $stderr.puts "Method failed IMMEDIATELY (raised Exception) ! #{err.class} => #{err.message}"
        end

        # - Can change email but ONLY to email that not already taken by someone (not even by current record
        #   since that wouldn't be an actual change anway)
        # . first should be ok
        $stderr.puts "       - email BEFORE change: #{gu.email.inspect}"
        gu.fieldUpdate(gu.login, 'email', "CHANGED-#{gu.email}") { |rs|
          $stderr.puts ">>>> D.6.1. RESULT SET FROM email (ok) UPDATE: #{rs.inspect}"
          $stderr.puts "       - same gu object's email AFTER change: #{gu.email.inspect}"

          # (next should fail)
          $stderr.puts "       - email BEFORE change: #{gu.email.inspect}"
          gu.fieldUpdate(gu.login, 'email', "andrewj@bcm.edu") { |rs|
            $stderr.puts ">>>> D.6.2. RESULT SET FROM email (conflict) UPDATE: #{rs.inspect}"
            $stderr.puts "       - same gu object's email AFTER change: #{gu.email.inspect}"

            # >>>>> Can we use upsert() to update various details of a user all at once?

            # - upsert various new info--includiing email to one that we know is NOT in use--we'll change all of them except lastName, say.
            gu.gbUserRec() { |xx| $stderr.puts "\n\nReview current record BEFORE change many values at once: #{xx.inspect}"
              gu.upsert( gu.login, "USR_UPDATE-#{gu.email}", "USR_UPDATE-#{gu.password}", "USR_UPDATE-#{gu.institution}", "USR_UPDATE-#{gu.firstName}", gu.lastName, "USR_UPDATE-#{gu.phone}" ) { |rs|
                $stderr.puts ">>>> E. RESULT SET FROM multi-field UPDATE: #{rs.inspect}"
                gu.gbUserRec() { |xx| $stderr.puts "       - record AFTER change many values at once #{xx[:rows].inspect}"

                  # - This should also work because although email is unchanged (and thus IN USE), it is in use BY THIS RECORD. Which is ok.
                  gu.upsert( gu.login, gu.email, "USR_UPDATE2-#{gu.password}", "USR_UPDATE2-#{gu.institution}", "USR_UPDATE2-#{gu.firstName}", gu.lastName, "USR_UPDATE2-#{gu.phone}" ) { |rs|
                    $stderr.puts ">>>> E.1. RESULT SET FROM multi-field UPDATE (email staying the same): #{rs.inspect}"
                    gu.gbUserRec() { |xx| $stderr.puts "       - record AFTER change many values at once #{xx[:rows].inspect}"

                      # - This should fail because email we're chaning to is in use by a different record.
                      gu.gbUserRec() { |xx| $stderr.puts xx.inspect }
                      gu.upsert( gu.login, 'andrewj@bcm.edu', "USR_UPDATE3-#{gu.password}", "USR_UPDATE3-#{gu.institution}", "USR_UPDATE3-#{gu.firstName}", gu.lastName, "USR_UPDATE3-#{gu.phone}" ) { |rs|
                        $stderr.puts ">>>> E.2. RESULT SET FROM multi-field UPDATE (attempt email change to already-in-use-email): #{rs.inspect}"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

# >> Check un-rescued powerful Exception in dev callback. Is it caught & handled, thus protecting?  <<

seed = "#{$$}-#{rand(1000)}"
EM.run {

  # - Here is a completely deranged situation where the dev didn't even provide a callback, which is an ArgumentError
  #   for most of the library methods. But even here, it will attempt to catch the problem--which is not in dev's callback
  #   but rather THEY GAVE NO CALLBACK--and attempt to reply to the client directly, as in cases above.
  #   (This one happens immediately, because others have the callbacks put into the event loop, whereas this has no callback at all!)
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '')


  # As each of these is done, EM loop should keep going, not break like it would for a powerful Exception.
  #   ( Compare that to EM.run { EM.next_tick { raise Exception, "die!!" } } which is effectively what dev is
  #     is doing by using :obj blindly (no such method exception is a powerful one) or not-rescuing exceptions
  #     and sending back sensible http code and payload to client THEMSELVES (so we do it for them...) )

  # - Should be noticed/logged with a trace, but then the Rack callback should be called directly with a custom triple
  #   that contains an error JSON.
  GbDb::GbUser.byUserId(rackEnv, 2 ) {
    $stderr.puts "\nCASE 1: Powerful exception raised within factory method."
    raise SyntaxError, "syntax!"
  }

  # - Should create the new record, but then dev exception (no such method no_such_method for nil) should be
  #     noticed/logged, and then Rack callback should be called directly with code 500 via custom triple.
  #     Verify manually that record was created.
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts "\nCASE 2: Creation method works, making new user (as we'll see), but then silly dev code raises powerful exception."
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    # Silly dev...
    nil.no_such_method
    # Code after this won't be reached...but verify
    $stderr.puts "We made it past our silly code mistake? Probably not. This whole callback block stops upon exception."
  }

  # - In this more likely/natural failure by the dev, they just waltz forward assuming that result[:obj] is available,
  #   whereas they SHOULD have checked for it first (and perhaps :err, where there is indeed information). This results in
  #   un-rescued exception from the dev callback code...which is caught and logged and results in direct response
  gu = nil ; GbDb::GbUser.create(rackEnv, "arj-test-#{seed}", "#{seed}@nowhere.net", "xx#{seed}xx", 'Nowhere Inc', 'No', 'Where', '') { |rs|
    $stderr.puts "\nCASE 3: Likely/natural situation. Library returns error in :err key--we created the user record already in the previously queued request (should have been handled in the prior tick). But dev doesn't check :obj nor handle :err appropriately for their application..."
    $stderr.puts ">>>> RESULT SET FROM CREATE: #{rs.inspect}"
    # Dev assumes rs[:obj] is present and fails to check first
    rs[:obj].userId * 7
  }

}