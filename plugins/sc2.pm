use LWP::Simple;
use HTML::TreeBuilder;
use Data::Dumper;
use strict;

my %UNIT_MAP = (
	'battlecruiser' => '/game/terran/units/battlecruiser',
	'high templar' => '/game/protoss/units/high-templar',
	'viking' => '/game/terran/units/viking',
	'warp prism' => '/game/protoss/units/warp-prism',
	'brood lord' => '/game/zerg/units/brood-lord',
	'larva' => '/game/zerg/units/larva',
	'terran banshee' => '/game/terran/units/banshee',
	'mutalisk' => '/game/zerg/units/mutalisk',
	'overseer' => '/game/zerg/units/overseer',
	'point defense drone' => '/game/terran/units/point-defense-drone',
	'interceptors' => '/game/protoss/units/interceptors',
	'dark templar' => '/game/protoss/units/dark-templar',
	'baneling' => '/game/zerg/units/baneling',
	'mule' => '/game/terran/units/mule',
	'sentry' => '/game/protoss/units/sentry',
	'queen' => '/game/zerg/units/queen',
	'auto-turret' => '/game/terran/units/auto-turret',
	'marauder' => '/game/terran/units/marauder',
	'scv' => '/game/terran/units/scv',
	'hydralisk' => '/game/zerg/units/hydralisk',
	'banshee' => '/game/terran/units/banshee',
	'mothership' => '/game/protoss/units/mothership',
	'infestor' => '/game/zerg/units/infestor',
	'changeling' => '/game/zerg/units/changeling',
	'phoenix' => '/game/protoss/units/phoenix',
	'roach' => '/game/zerg/units/roach',
	'zergling' => '/game/zerg/units/zergling',
	'overlord' => '/game/zerg/units/overlord',
	'corruptor' => '/game/zerg/units/corruptor',
	'probe' => '/game/protoss/units/probe',
	'ultralisk' => '/game/zerg/units/ultralisk',
	'stalker' => '/game/protoss/units/stalker',
	'reaper' => '/game/terran/units/reaper',
	'observer' => '/game/protoss/units/observer',
	'archon' => '/game/protoss/units/archon',
	'carrier' => '/game/protoss/units/carrier',
	'infested terran' => '/game/zerg/units/infested-terran',
	'drone' => '/game/zerg/units/drone',
	'marine' => '/game/terran/units/marine',
	'immortal' => '/game/protoss/units/immortal',
	'void ray' => '/game/protoss/units/void-ray',
	'zerg nydus worm' => '/game/zerg/units/nydus-worm',
	'ghost' => '/game/terran/units/ghost',
	'raven' => '/game/terran/units/raven',
	'siege tank' => '/game/terran/units/siege-tank',
	'zealot' => '/game/protoss/units/zealot',
	'broodling' => '/game/zerg/units/broodling',
	'colossus' => '/game/protoss/units/colossus',
	'nydus worm' => '/game/zerg/units/nydus-worm',
	'medivac' => '/game/terran/units/medivac',
	'thor' => '/game/terran/units/thor',
	'hellion' => '/game/terran/units/hellion'
);



sub {
	my( $said ) = @_;
	my $unit = lc $said->{body};

	if( not $UNIT_MAP{$unit} ) {
		print "Error, unit doesn't look valid.";
		return;
	}

	my $page = get "http://www.sc2armory.com$UNIT_MAP{$unit}";

	my $tree = HTML::TreeBuilder->new_from_content( $page ) ;

	my %stats;
	for( $tree->look_down( class => 'dataList' ) ) {
		for( $_->look_down(_tag => 'li') ){
			my( $k,$v ) = split /\s*:\s*/,$_->as_text;

			$stats{lc$k}=$v;
		}
	}

	my $name = $tree->look_down( _tag => 'title' )->as_text;
	$name =~ s/Starcraft 2 Armory - //;

	#Minerals: 75 Hotkey: R Hit Points: 145 Mutater: Larva Speed: Normal Build Time: 27 Movement: Normal Modifiers: Armored - Biological Acid Saliva:  Requires: Roach Warren Damage: 16 (+2) Supply: 1 Range: 3 Targets: Ground Vespene: 25 Armor: 2 (+1) 

	my $bonus = $stats{bonus} ? " Bonus: $stats{bonus};" : "";
	my $shields = $stats{shields} ? "$stats{shields}+":"";
	print "$name - Cost [$stats{minerals}/$stats{vespene}/$stats{'build time'}s] HP/A/D: $shields$stats{'hit points'}/$stats{damage}/$stats{armor} - $stats{modifiers};$bonus Range: $stats{range}, Speed: $stats{movement};";
}


__DATA__
sc2 <UNIT NAME>; Looks up starcraft2 unit and returns its stats.

