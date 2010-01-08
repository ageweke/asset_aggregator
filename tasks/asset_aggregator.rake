namespace :asset do
  namespace :aggregator do
    desc "Builds asset_aggregator files for static deployment"
    task :build => :environment do
      $_asset_aggregator_allow_aggregated_files = true
      AssetAggregator.write_aggregated_files(true)
    end
  
    desc "Cleans asset_aggregator files from static deployment"
    task :clean => :environment do
      $_asset_aggregator_allow_aggregated_files = true
      AssetAggregator.remove_aggregated_files
    end
  end
end
