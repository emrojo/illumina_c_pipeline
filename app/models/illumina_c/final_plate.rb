class IlluminaC::FinalPlate < Sequencescape::Plate
  # We need to specialise the transfers where this plate is a source so that it handles
  # the correct types
  class Transfer < ::Sequencescape::Transfer
    belongs_to :source, :class_name => 'FinalPlate', :disposition => :inline
    attribute_reader :transfers

    def transfers_with_tube_mapping=(transfers)
      send(
        :transfers_without_tube_mapping=, Hash[
          transfers.map do |well, tube_json|
            [ well, ::IlluminaC::StockLibraryTube.new(api, tube_json, false) ]
          end
        ]
      )
    end
    alias_method_chain(:transfers=, :tube_mapping)
  end

  has_many :transfers_to_tubes, :class_name => 'FinalPlate::Transfer'

  def well_to_tube_transfers
    @transfers ||= transfers_to_tubes.inject({}) {|all,ttt| all.merge(ttt.transfers) }
  end

  # We know that if there are any transfers with this plate as a source then they are into
  # tubes.
  def has_transfers_to_tubes?
    not transfers_to_tubes.empty?
  end

  # Well locations ordered by rows.
  WELLS_IN_ROW_MAJOR_ORDER    = ('A'..'H').each_with_object([]) { |r,a| a.concat((1..12).map { |c| "#{r}#{c}" }) }
  WELLS_IN_COLUMN_MAJOR_ORDER = (1..12).each_with_object([]) { |c,a| a.concat(('A'..'H').map { |r| "#{r}#{c}" }) }

  # Returns the tubes that an instance of this plate has been transferred into.
  def tubes
    @tubes ||= case has_transfers_to_tubes?
       when false then []
       when true  then
         WELLS_IN_COLUMN_MAJOR_ORDER.
           map(&well_to_tube_transfers.method(:[])).
           compact.
           uniq
       end
  end

  def tubes_and_sources
    @tubes_and_sources ||= case has_transfers_to_tubes?
     when false then []
     when true then
       WELLS_IN_COLUMN_MAJOR_ORDER.map do |l|
          [l, well_to_tube_transfers[l]]
        end.group_by do |_, t|
          t && t.uuid
        end.reject do |uuid, _|
          uuid.nil?
        end.map do |_, well_tube_pairs|
          [well_tube_pairs.first.last, well_tube_pairs.map(&:first)]
        end
    end
  end

end
