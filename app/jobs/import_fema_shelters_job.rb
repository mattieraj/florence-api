class ImportFemaSheltersJob < ApplicationJob
  queue_as :default

  def perform(*args)
    logger.info "Starting ImportFemaSheltersJob #{Time.now}"
    fema_data = FemaImporter.shelters
    duplicates = 0
    fema_data.each do |data|
      if duplicate?(data)
        duplicates += 1
      else
        Shelter.create!(data)
      end
    end
    logger.info "ImportFemaSheltersJob Complete - Imported Shelters: #{fema_data.count - duplicates}"
  end

private

  def duplicate?(data)
    # This is a very naive deduplication effort, yes it does
    # an unindexed scan of the database against several columns of text
    #
    # TODO: Use Arel for the where named functions

    arel = Shelter.arel_table
    cnt = Shelter.unscope(:where).where(
          'LOWER(TRIM(shelter)) = ? AND LOWER(TRIM(city)) = ? AND LOWER(TRIM(state)) = ? AND LOWER(TRIM(zip)) = ?',
          data[:shelter].strip.downcase, data[:city].strip.downcase, data[:state].strip.downcase, data[:zip].strip.downcase
        ).count
    cnt += Shelter.unscope(:where).where('LOWER(TRIM(address)) = ?', data[:address].strip.downcase).count
    cnt += Shelter.unscope(:where).where('LOWER(TRIM(source)) = ?', data[:source].strip.downcase).count

    if cnt > 0
      logger.info "Duplicate: #{data[:shelter]} @ #{data[:address]}"
      true
    else
      false
    end
  end
end