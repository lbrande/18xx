# frozen_string_literal: true

module Engine
  class Connection
    attr_accessor :node_a, :node_b, :paths

    def self.layable_hexes(connections)
      hexes = Hash.new { |h, k| h[k] = [] }
      explored_connections = {}
      explored_paths = {}
      queue = []

      connections.each do |connection|
        puts "connection - #{connection.inspect}"
        queue << connection
      end

      while queue.any?
        connection = queue.pop
        explored_connections[connection] = true

        connection.paths.each do |path|
          next if explored_paths[path]

          explored_paths[path] = true
          hex = path.hex
          exits = path.exits
          puts "visit #{hex.inspect} #{exits}"
          hexes[hex] |= exits

          exits.each do |edge|
            neighbor = hex.neighbors[edge]
            edge = hex.invert(edge)
            next if neighbor.connections[edge].any?
            puts "coming to neighbor #{neighbor.inspect} #{edge}"
            hexes[neighbor] |= [edge]
          end
        end

        connection.connections.each do |c|
          queue << c unless explored_connections[c]
        end
      end

      hexes.default = nil
      puts hexes

      hexes
    end

    def initialize(node_a, node_b, paths)
      @node_a = node_a
      @node_b = node_b
      @paths = paths
    end

    def branch(path)
      self.class.new(
        @node_a,
        @node_b,
        @paths.reject { |p| p.hex == path.hex } + [path],
      )
    end

    def hexes
      @paths.map(&:hex)
    end

    def stops
      @paths.map(&:stop).uniq
    end

    def connections
      @node_a.hex.all_connections + (@node_b&.hex&.all_connections || [])
    end

    def tokened_by?(corporation)
      (@node_a&.city? && @node_a.tokened_by?(corporation)) ||
        (@node_b&.city? && @node_b.tokened_by?(corporation))
    end

    def inspect
      path_str = @paths.map(&:inspect).join(',')
      "<#{self.class.name}: node_a: #{@node_a&.hex&.name}, node_b: #{@node_b&.hex&.name}, paths: #{path_str}>"
    end
  end
end
