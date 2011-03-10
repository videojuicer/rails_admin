module RailsAdmin
  class History
    include DataMapper::Resource

    class QueryError < StandardError; end

    storage_names[:default] = 'rails_admin_histories'

    IGNORED_ATTRS = Set[:id, :created_at, :created_on, :deleted_at, :updated_at, :updated_on, :deleted_on]

    property :id,       Serial
    property :message,  String
    property :username, String
    property :item,     Integer
    property :table,    String
    property :month,    Integer, :set => 1..12
    property :year,     Integer, :min => 2010, :max => 2020

    timestamps :at

    # TODO: evaluate performance and add indexes as needed

    def self.most_recent(table)
      all(:table => table, :order => [ :updated_at ])
    end

    def self.get_history_for_dates(mstart, mstop, ystart, ystop)
      rows = if mstart > mstop
        aggregate(:all.count, :fields => [ :year, :month ], :month => mstart + 1..12, :year => ystart) |
        aggregate(:all.count, :fields => [ :year, :month ], :month => 1..mstop,       :year => ystop)
      else
        aggregate(:all.count, :fields => [ :year, :month ], :month => mstart + 1..mstop, :year => ystart)
      end

      result_class = Struct.new(:year, :month, :number)
      results      = rows.map { |row| result_class.new(*row) }

      add_blank_results(results, mstart, ystart)
    rescue => e
      raise QueryError, e.message, e.backtrace
    end

    def self.add_blank_results(results, mstart, ystart)
      # fill in an array with BlankHistory
      blanks = Array.new(5) { |i| BlankHistory.new(((mstart+i) % 12)+1, ystart + ((mstart+i)/12)) }
      # replace BlankHistory array entries with the real History entries that were provided
      blanks.each_index do |i|
        if results[0] && results[0].year == blanks[i].year && results[0].month == blanks[i].month
          blanks[i] = results.delete_at 0
        end
      end
    end
  end
end
