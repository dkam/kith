# While nobody has joined, every boot prints the setup code. It is the only
# credential that exists before the first member does, and the console is the
# only place it is ever shown.
#
# after_initialize rather than at load: the database has to be there to know
# whether anybody has joined, and Setup.announce stays quiet if it isn't.
Rails.application.config.after_initialize do
  Setup.announce unless Rails.env.test?
end
