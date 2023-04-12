desc 'Initialize database'
task :initialize_db do
  system 'createdb buzzle && psql -d buzzle < ./db/schema.sql'
end