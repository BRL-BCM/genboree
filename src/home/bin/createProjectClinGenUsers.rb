#!/usr/bin/env ruby

require 'genboreeTools'

# create project for work
redmine_add_project("clingen_users", "ClinGen Users", ['register_clingen_user'], true)
redmine_configure_project_register_clingen_user("clingen_users")
redmine_assign_user_to_project("genbadmin", "clingen_users", ['manager', 'developer', 'reporter'])

puts "Completed!"
