namespace :asset_aggregator do
  desc "Builds asset_aggregator files"
  task :build do
    Dir.chdir(::Rails.root) do
      exec("ruby script/runner vendor/plugins/asset_aggregator/tasks/build.rb")
    end
  end
  
  desc "Cleans asset_aggregator files"
  task :clean do
    Dir.chdir(::Rails.root) do
      exec("ruby script/runner vendor/plugins/asset_aggregator/tasks/clean.rb")
    end
  end
end
