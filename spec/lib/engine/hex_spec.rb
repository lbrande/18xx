# frozen_string_literal: true

require './spec/spec_helper'

require 'engine'

module Engine
  describe Hex do
    let(:game) { GAMES_BY_TITLE['1889'].new(['a', 'b']) }
    subject { game.hex_by_id('H7') }
#
    describe '#neighbor_direction' do
      it 'is a neighbor' do
        expect(subject.neighbor_direction(game.hex_by_id('I8'))).to eq(5)
      end

      it 'is not a neighbor' do
        expect(subject.neighbor_direction(game.hex_by_id('I4'))).to be_falsey
      end
    end

    describe '#connected?' do
      before :each do
        subject.lay(game.tile_by_id('57-0'))
      end

      let(:neighbor) { game.hex_by_id('H5') }

      it 'is connected' do
        neighbor.lay(game.tile_by_id('9-1'))
        expect(subject.connected?(neighbor)).to be_truthy
      end

      it 'is not connected with no tiles' do
        expect(subject.connected?(neighbor)).to be_falsey
      end

      it 'is not connected with wrong rotation' do
        tile = game.tile_by_id('9-0')
        tile.rotate!(1)
        neighbor.lay(tile)
        expect(subject.connected?(neighbor)).to be_falsey
      end
    end

    describe '#lay' do
      let(:green_tile) { game.tile_by_id('15-0') }
      let(:brown_tile) { game.tile_by_id('611-0') }
      let(:corp_1) { game.corporation_by_id('AR') }
      let(:corp_2) { game.corporation_by_id('IR') }

      context 'laying green' do
        it 'sets @tile to the given tile' do
          subject.lay(green_tile)
          expect(subject.tile).to have_attributes(name: '15')
        end

        it 'preserves a placed token' do
          subject.tile.cities[0].place_token(corp_1)

          subject.lay(green_tile)
          expect(subject.tile.cities[0].tokens[0]).to have_attributes(corporation: corp_1)
          expect(subject.tile.cities[0].tokens[1]).to be_nil
        end

        it 'preserves a token reservation' do
          subject.tile.cities[0].reservations = ['AR']

          subject.lay(green_tile)
          expect(subject.tile.cities[0].reservations).to eq(['AR'])
        end
      end

      context 'laying brown' do
        before(:each) { subject.lay(green_tile) }

        it 'sets @tile to the given tile' do
          subject.lay(brown_tile)

          expect(subject.tile).to have_attributes(name: '611')
        end

        it 'preserves a placed token' do
          subject.tile.cities[0].place_token(corp_1)

          subject.lay(brown_tile)
          expect(subject.tile.cities[0].tokens[0]).to have_attributes(corporation: corp_1)
          expect(subject.tile.cities[0].tokens[1]).to be_nil
        end

        it 'preserves 2 placed tokens' do
          subject.tile.cities[0].place_token(corp_1)
          subject.tile.cities[0].place_token(corp_2)

          subject.lay(brown_tile)

          expect(subject.tile.cities[0].tokens[0]).to have_attributes(
            corporation: corp_1,
            used?: true,
          )

          expect(subject.tile.cities[0].tokens[1]).to have_attributes(
            corporation: corp_2,
            used?: true,
          )
        end

        it 'preserves a placed token and a reservation' do
          subject.tile.cities[0].reservations = ['AR']
          subject.tile.cities[0].place_token(corp_2)

          subject.lay(brown_tile)

          expect(subject.tile.cities[0].tokens[0]).to be_nil
          expect(subject.tile.cities[0].tokens[1]).to have_attributes(corporation: corp_2)
          expect(subject.tile.cities[0].reservations).to eq(['AR'])
        end
      end
    end

    describe '#connect' do
      let(:neighbor_3) { subject.neighbors[3] }

      before :each do
        subject.lay(game.tile_by_id('57-0'))
        neighbor_3.lay(game.tile_by_id('9-0'))
      end

      it 'connects on a new edge' do
        node = subject.tile.paths[0].node

        expect(subject.connections.size).to eq(2)

        expect(subject.connections[0].size).to eq(1)
        expect(subject.connections[0][0]).to have_attributes(
          node_a: node,
          node_b: nil,
          hexes: [subject],
        )

        expect(subject.connections[3].size).to eq(1)
        expect(subject.connections[3][0]).to have_attributes(
          node_a: node,
          node_b: nil,
          hexes: [subject, neighbor_3]
        )
      end

      it 'connects on an upgrade' do
        neighbor_3.lay(game.tile_by_id('23-0'))
        connections_0 = subject.connections[0]
        expect(connections_0.size).to eq(1)
        expect(connections_0[0]).to have_attributes(
          node_a: subject.tile.cities[0],
          node_b: nil,
          paths: [subject.tile.paths[0]],
        )

        connections_3 = subject.connections[3]
        expect(connections_3.size).to eq(2)
        expect(connections_3[0]).to have_attributes(
          node_a: subject.tile.cities[0],
          node_b: nil,
          paths: [subject.tile.paths[1], neighbor_3.tile.paths[0]],
        )
        expect(connections_3[1]).to have_attributes(
          node_a: subject.tile.cities[0],
          node_b: nil,
          paths: [subject.tile.paths[1], neighbor_3.tile.paths[1]],
        )
      end

      it 'connects complex' do
        hex = game.hex_by_id('K8')
        hex.lay(game.tile_by_id('6-0').rotate!(2))
        game.hex_by_id('I8').lay(game.tile_by_id('7-0').rotate!(4))
        game.hex_by_id('I6').lay(game.tile_by_id('9-0'))
        game.hex_by_id('I6').lay(game.tile_by_id('23-0'))

        ritsurin = game.hex_by_id('J5')
        ritsurin.lay(game.tile_by_id('3-0').rotate!(1))

        expect(hex.all_connections.size).to eq(3)

        naruoto = game.hex_by_id('L7')
        expect(hex.connections[4][0]).to have_attributes(
          node_a: hex.tile.cities[0],
          node_b: naruoto.tile.offboards[0],
          paths: [hex.tile.paths[1], naruoto.tile.paths[0]],
        )

        expect(hex.connections[2][0]).to have_attributes(
          node_a: hex.tile.cities[0],
          node_b: nil,
          paths: [],
        )

        expect(hex.connections[2][1]).to have_attributes(
          node_a: hex.tile.cities[0],
          node_b: ritsurin.tile.towns[0],
          paths: [],
        )
      end
    end
  end
end
