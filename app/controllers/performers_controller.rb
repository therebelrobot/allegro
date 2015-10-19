require 'base64'
require 'csv'
require 'groupanizer_scraper'

class PerformersController < ApplicationController
  def index
    @performers = Performer.all.includes(:registrations)
  end

  def printcards
    @concert = Concert.current
    @registrations = Registration.where(:concert => @concert).includes(:performer).order('chorus_number')
    if params[:chorus_number]
      numbers = params[:chorus_number].split(',').map do |number|
        parts = number.split('-')
        if parts.length == 2
          Range.new(*parts)
        else
          number
        end
      end

      @registrations = @registrations.where(:chorus_number => numbers)
    end
  end

  def photo
    @performer = Performer.find(params[:id])
    if @performer.photo
      render :text => @performer.photo, :content_type => 'image/png'
    else
      # TODO(nharper): consider changing to clear.gif
      # http://upload.wikimedia.org/wikipedia/en/d/d0/Clear.gif
      #
      # 1x1 transparent png; source: http://garethrees.org/2007/11/14/pngcrush/
      render :text => Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=='), :content_type => 'image/png'
    end
  end

  def newcard
    @card = Card.new(:performer => Performer.find(params[:id]))
  end

  def upload_csv
  end

  def import
    concert = Concert.current
    raise "No current concert" unless concert

    performers = Performer.all.index_by(&:foreign_key)
    registrations = Registration.where(:concert => concert).index_by(&:performer_id)

    csv_file = params[:csv]
    csv_data = csv_file.read
    GroupanizerScraper::parse_csv(csv_data).each do |_, entry|
      performer = performers[entry['foreign_key']]
      if !performer
        performer = Performer.new
        performer.foreign_key = entry['foreign_key']
      end
      performer.name = entry['name']

      registration = registrations[performer.id]
      if registration == nil
        registration = Registration.new
      end

      registration.full_section = entry['voice_part']
      next if !registration.section # && entry['status'] != :active
      registration.chorus_number = entry['chorus_number']
      registration.status = entry['status']
      registration.performer = performer
      registration.concert = concert

      performer.save!
      if entry['status'] == :alumni
        registration.destroy!
      else
        if !registration.save
          registration.chorus_number = "RAND#{800 + SecureRandom.random_number(200)}"
          registration.save!
        end
      end
    end
  end
end
