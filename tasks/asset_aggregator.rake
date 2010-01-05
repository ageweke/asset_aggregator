namespace :asset_aggregator do
  task :init_rails do
    $_asset_aggregator_allow_aggregated_files = true
    
    require File.join(::Rails.root, 'config', 'boot')
    require File.join(::Rails.root, 'config', 'environment')
  end
  
  desc "Builds asset_aggregator files"
  task :build => :init_rails do
    AssetAggregator.write_aggregated_files
  end
  
  desc "Cleans asset_aggregator files"
  task :clean => :init_rails do
    AssetAggregator.remove_aggregated_files
  end
end
