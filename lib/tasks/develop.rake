namespace :develop do
  task bootstrap: [:'db:migrate'] do
    unless User.where(email: 'admin@example.com').any?
      puts "Creating admin user"
      user = User.new(
        email: 'admin@example.com',
        password: 'password'
      )
      user.skip_confirmation!
      user.save!
    end

    puts 'Bootstraped!'
  end
end
