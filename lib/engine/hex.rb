# frozen_string_literal: true

require_relative 'connection'

module Engine
  class Hex
    attr_reader :connections, :coordinates, :layout, :neighbors, :tile, :x, :y, :location_name

    DIRECTIONS = {
      flat: {
        [0, 2] => 0,
        [-1, 1] => 1,
        [-1, -1] => 2,
        [0, -2] => 3,
        [1, -1] => 4,
        [1, 1] => 5,
      },
      pointy: {
        [1, 1] => 0,
        [-1, 1] => 1,
        [-2, 0] => 2,
        [-1, -1] => 3,
        [1, -1] => 4,
        [2, 0] => 5,
      },
    }.freeze

    LETTERS = ('A'..'Z').to_a

    def self.invert(dir)
      (dir + 3) % 6
    end

    # Coordinates are of the form A1..Z99
    # x and y map to the double coordinate system
    # layout is pointy or flat
    def initialize(coordinates, layout: :pointy, tile: Tile.for('blank'), location_name: nil)
      @coordinates = coordinates
      @layout = layout
      @x = LETTERS.index(@coordinates[0]).to_i
      @y = @coordinates[1..-1].to_i - 1
      @neighbors = {}
      @connections = Hash.new { |h, k| h[k] = [] }
      @location_name = location_name
      tile.location_name = location_name
      @tile = tile
      @tile.hex = self
    end

    def id
      @coordinates
    end

    def name
      @coordinates
    end

    def lay(tile)
      # when upgrading, preserve tokens (both reserved and actually placed) on
      # previous tile
      @tile.cities.each_with_index do |city, i|
        tile.cities[i].reservations = city.reservations.dup

        city.tokens.each do |token|
          tile.cities[i].exchange_token(token) if token
        end
        city.remove_tokens!
        city.reservations.clear
      end

      disconnect

      puts "** making #{@tile.hex.name} nil"
      @tile.hex = nil
      tile.hex = self

      # give the city/town name of this hex to the new tile; remove it from the
      # old one
      tile.location_name = @location_name
      @tile.location_name = nil
      @tile = tile

      connect
    end

    def all_connections
      @connections.values.flatten
    end

    def disconnect
      nodes = @tile.nodes
      paths = @tile.paths
      puts "** disconnecting #{@connections}"

      all_connections.each do |connection|
        connection.paths.each do |path|
          puts "preparing to disconnect #{connection.object_id} #{path.exits} #{path.hex.name}"
        end
        connection.paths -= paths
        connection.paths.each do |path|
          puts "after disconnect #{path.exits} #{path.hex.name}"
        end

        if nodes.any? { |n| n == connection.node_a }
          connection.node_a = connection.node_b
          connection.node_b = nil
        elsif nodes.any? { |n| n == connection.node_b }
          connection.node_b = nil
        end
      end
    end

    def connect(edge = nil)
      paths = @tile.paths.select { |p| !edge || p.exits.include?(edge) }

      paths.each do |path|
        path.node ? connect_node(path) : connect_edge(path)
      end
    end

    def connect_node(path)
      puts "connecting node #{@coordinates} #{path.exits} #{path.tile.name}"
      node = path.node
      edge = path.exits[0]

      neighbor = @neighbors[edge]
      n_edge = invert(edge)
      connections = neighbor.connections[n_edge]
      if connections.any?
        connections.each do |connection|
          connection.node_a ? connection.node_b = node : connection.node_a = node
          connection.paths << path
          @connections[edge] << connection
        end
        puts "adding connectios from neighbors #{@connections.inspect}"
      else
        connection = Connection.new(node, nil, [path])
        @connections[edge] << connection
        # neighbor.connections[n_edge] << connection
        neighbor.connect(n_edge)
        puts "new connection #{edge} - #{n_edge} #{@connections.inspect}"
      end
    end

    def connect_edge(path)
      puts "connecting edge #{@coordinates} #{path.exits} - #{path.hex&.name}"
      edge_a, edge_b = path.exits

      neighbor_a = @neighbors[edge_a]
      neighbor_b = @neighbors[edge_b]

      n_edge_a = invert(edge_a)
      n_edge_b = invert(edge_b)

      puts "** neighbor a connections #{edge_a} #{neighbor_a.connections}"
      connections_a = neighbor_a.connections[n_edge_a]
      connections_b = neighbor_b.connections[n_edge_b]

      connections =
        if connections_a.any? && connections_b.any?
          puts "both exists"
          connections_a.flat_map do |connection_a|
            connections_b.map do |connection_b|
              Connection.new(
                connection_a.node_a,
                connection_b.node_b || connection_b.node_a,
                connection_a.paths | connection_b.paths,
              )
            end
          end
        else
          connections_a + connections_b
        end
      puts "merged #{connections.inspect}"

      connections.flat_map(&:paths).each do |path|
        path.exits.each do |edge|
          path.hex.connections[edge].clear
        end
      end

      connections = connections.flat_map do |connection|
        if connection.hexes.include?(path.hex)
          puts "** branching ** "
          puts connection.inspect
          puts connection.branch(path).inspect
          [connection, connection.branch(path)]
        else
          puts "** just adding path ** "
          connection.paths << path
          [connection]
        end
      end

      connections.each do |connection|
        connection.paths.each do |path|
          path.exits.each do |edge|
            puts "** adding connection to hex #{path.hex.name} #{edge} #{connection.object_id}"
            path.hex.connections[edge] << connection
          end
        end
      end
    end

    def neighbor_direction(other)
      DIRECTIONS[@layout][[other.x - @x, other.y - @y]]
    end

    def targeting?(other)
      dir = neighbor_direction(other)
      @tile.exits.include?(dir)
    end

    def invert(dir)
      self.class.invert(dir)
    end

    def inspect
      "<#{self.class.name}: #{name}, tile: #{@tile.name}>"
    end
  end
end
