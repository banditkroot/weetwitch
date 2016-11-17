use strict;
use warnings;
use JSON qw(decode_json);
use Try::Tiny;

my $token = ""; #Your Twitch Token here !
my $clientid = ""; #Your client-id here !
my $sc_name = "WeeTwitch";
my $version = "0.64";
my ($channel, $server, $json, $decode, $live, $game, $user, $mature, $follow, $buffer, $partner, $clear_str, $incr, $twitch_un);
my (@stream, @clear, @liste); #Récupère les streams en cours dans le tableau streams[] de $decode

weechat::register($sc_name, "BOUTARD Florent <bandit.kroot\@gmail.com", $version, "GPL3", "Lance les streams Twitch.tv", "unload", "");
$twitch_un = weechat::info_get("irc_nick", "twitch");
weechat::hook_command("whostream", "Juste taper /whostream.", "", "", "", "who_stream", "");
weechat::hook_command("whotwitch", "Taper /whotwitch et le nom d\'un utilisateur.", "", "", "", "whotwitch", "");
weechat::hook_command("stream", "Juste taper /stream dans le channel désiré.", "", "", "", "stream", "");
weechat::hook_command("viewers", "Juste taper /viewers.", "", "", "", "viewer", "");
weechat::hook_command("follow", "Juste taper /follow.", "", "", "", "follow", "");
weechat::hook_command("unfollow", "Juste taper /unfollow.", "", "", "", "unfollow", "");
weechat::hook_modifier("irc_in_USERSTATE", "userroomstate_cb", "");
weechat::hook_modifier("irc_in_ROOMSTATE", "userroomstate_cb", "");
weechat::hook_modifier("irc_in_HOSTTARGET", "userroomstate_cb", "");
weechat::hook_modifier("irc_in_USERNOTICE", "userroomstate_cb", "");
weechat::hook_modifier("irc_in_CLEARCHAT", "clearchat_cb", "");

#Commande /whostream
sub who_stream {
	buffer();
	try {
		$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Authorization: OAuth $token' -X GET https://api.twitch.tv/kraken/streams/followed`;
		$decode = decode_json($json);
		$live = $decode->{'_total'};
		@stream = @{$decode->{'streams'}};
		@liste = undef;
		$incr = 1;
		if ($live eq "0") {
			weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Pas de stream en cours...");
			return weechat::WEECHAT_RC_OK;
		}
		weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Stream en cours :" . weechat::color("-bold"));
		foreach my $displayname (@stream) {
			if ($displayname->{'channel'}{'game'}) {
				$game = "du " . weechat::color("bold") . $displayname->{'channel'}{'game'} . weechat::color("-bold");
			}
			else {
				$game = "aucun jeu";
			}
			if ($displayname->{'channel'}{'mature'}) {
				$mature = "en mature avec";
			}
			else {
				$mature = "avec";
			}
			if ($displayname->{'channel'}{'partner'}) {
				$partner = weechat::color("yellow") . $incr;
			}
			else {
				$partner = $incr;
			}
			$incr++;
			push @liste, lc($displayname->{'channel'}{'display_name'});
			weechat::print($buffer, "$partner\t" . weechat::color("bold") . "$displayname->{'channel'}{'display_name'}" . weechat::color("-bold") . " stream $game $mature $displayname->{'viewers'} spectateurs.");
		}
	}
	catch {
		weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Impossible de vérifier les streams en cours...");
	};
	return weechat::WEECHAT_RC_OK;
}

#whotwitch pour remplacer le whois
sub whotwitch {
	$user = lc($_[2]);
	if ($user) {
		buffer();
		$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/users/$user`;
		$decode = decode_json($json);
		weechat::print("$buffer","Utilisateur\t". weechat::color("bold") . $decode->{'display_name'} . weechat::color("-bold"));
		weechat::print("$buffer","Type\t$decode->{'type'}");
		if ($decode->{'bio'}) { weechat::print("$buffer","Bio\t$decode->{'bio'}"); }
		weechat::print("$buffer","Créé le\t" . substr($decode->{'created_at'},8,2) . "/" . substr($decode->{'created_at'},5,2) . "/" . substr($decode->{'created_at'},0,4) . " à " . substr($decode->{'created_at'},11,8));
		weechat::print("$buffer","Dernière MAJ\t" . substr($decode->{'updated_at'},8,2) . "/" . substr($decode->{'updated_at'},5,2) . "/" . substr($decode->{'updated_at'},0,4) . " à " . substr($decode->{'updated_at'},11,8));
		$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Client-ID: $clientid'  -X GET https://api.twitch.tv/kraken/users/$user/follows/channels`;
		$decode = decode_json($json);
		if ($decode->{'_total'} eq "1") {
			@stream = @{$decode->{'follows'}};
			foreach my $displayfollow (@stream) {
				$follow = " : " . $displayfollow->{'channel'}{'name'};
			}
		}
		else {
			$follow = "s.";
		}
		weechat::print("$buffer","Il follow\t" . $decode->{'_total'} . " personne" . $follow);
		weechat::print("$buffer","URL\thttp://twitch.tv/$user/profile");
	}
	return weechat::WEECHAT_RC_OK;
}

#Gère la commande /stream
sub stream {
	buffer();
	if (server()) {
		weechat::print($buffer, "---\tLancement du stream twitch.tv/$channel...");
		try {
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/streams/$channel`;
			$decode = decode_json($json);
			$live = $decode->{'stream'};
			if ($live) {
				weechat::buffer_set(weechat::current_buffer(), "title", $decode->{'stream'}{'channel'}{'status'});
				weechat::print($buffer, "Titre\t$decode->{'stream'}{'channel'}{'status'}");
				weechat::print($buffer, "Jeu en cours\t$decode->{'stream'}{'game'}");
				weechat::print($buffer, "Spectateurs\t$decode->{'stream'}{'viewers'}");
				weechat::print($buffer, "Commencé\tle " . substr($decode->{'stream'}{'created_at'},8,2) . "/" . substr($decode->{'stream'}{'created_at'},5,2) . "/" . substr($decode->{'stream'}{'created_at'},0,4) . " à " . substr($decode->{'stream'}{'created_at'},11,8));
				weechat::print($buffer, "Vidéo source\t$decode->{'stream'}{'video_height'}p à $decode->{'stream'}{'average_fps'}fps");
				weechat::print($buffer, "Délais\t$decode->{'stream'}{'delay'}");
				weechat::print($buffer, "Langage\t$decode->{'stream'}{'channel'}{'broadcaster_language'}");
				if ($decode->{'stream'}{'channel'}{'mature'}) { weechat::print($buffer, "*\tStream mature"); }
				if ($decode->{'stream'}{'channel'}{'partner'}) { weechat::print($buffer, "*\tStream partenaire"); }
			}
		}
		catch {
			weechat::print($buffer, "Impossible de récupérer le topic.");
		};
		weechat::hook_process("livestreamer twitch.tv/$channel", 0, "stream_end", "");
	}
	return weechat::WEECHAT_RC_OK;
}

#Fin de stream
sub stream_end {
	buffer();
	weechat::print($buffer, "Fin du stream.");
	return weechat::WEECHAT_RC_OK;
}

#Affiche les viewers
sub viewer {
	if (server()) {
		try {
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/streams/$channel`;
			$decode = decode_json($json);
			$live = $decode->{'stream'};
			if ($live) {
				weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "Actuellement $decode->{'stream'}{'viewers'} spectateurs.");
			}
			else {
				weechat::print(weechat::current_buffer(), "*\tPas de live en cours...");
			}
		}
		catch {
			weechat::print(weechat::current_buffer(), "*\tImpossible de récupérer le topic.");
		};
	}
	return weechat::WEECHAT_RC_OK;
}

#Suivre une chaine
sub follow {
	if (server()) {
		try {
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Authorization: OAuth $token' -X PUT https://api.twitch.tv/kraken/users/$twitch_un/follows/channels/$channel`;
			weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "Chaine suivie.");
		}
		catch {
			weechat::print(weechat::current_buffer(), "*\tImpossible de suivre la chaine.");
		};
	}
	return weechat::WEECHAT_RC_OK;
}

#Ne plus suivre une chaine
sub unfollow {
	if (server()) {
		try {
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v3+json' -H 'Authorization: OAuth $token' -X DELETE https://api.twitch.tv/kraken/users/$twitch_un/follows/channels/$channel`;
			weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "La chaine n'est plus suivie.");
		}
		catch {
			weechat::print(weechat::current_buffer(), "*\tImpossible de ne plus suivre la chaine.");
		};
	}
	return weechat::WEECHAT_RC_OK;
}

#Pour afficher le nouveau buffer
sub buffer {
	$buffer = weechat::buffer_search("perl", $sc_name);
	if ($buffer eq "") {
		$buffer = weechat::buffer_new($sc_name, "buffer_input", "", "", "");
		weechat::buffer_set($buffer, "title", "$sc_name $version     [q] pour quitter.");
	}
	else {
		weechat::print($buffer, weechat::color("yellow") . "*\t". weechat::color("magenta") . "-" x 10);
	}
}

#Pour joindre un cannal après un whostream
sub buffer_input {
	my ($data, $buff, $string) = ($_[0], $_[1], $_[2]);
	if ($string eq "q") {
		weechat::buffer_close($buff);
	}
	elsif ($string =~ m/^\d+$/) {
		if ($string <= $#liste) {
			weechat::command("", "/quote -server twitch JOIN #" . $liste[$string]);
			weechat::command("", "/wait 1s /stream");
		}
	}
	return weechat::WEECHAT_RC_OK;
}

#Vérification server et channel correct
sub server {
	if (weechat::buffer_get_string(weechat::current_buffer(), "localvar_type") eq "channel") {
		$server = weechat::buffer_get_string(weechat::current_buffer(), "localvar_server");
		$channel = substr(weechat::buffer_get_string(weechat::current_buffer(), "localvar_channel"), 1);
	}
	if ($server eq "twitch") {
		return 1;
	}
	else {
		weechat::print(weechat::current_buffer(), "*\tServeur et/ou channel non valide.");
		return 0;
	}
}

#Affiche les message d'expulsion de twitch
sub clearchat_cb {
	(undef, undef, undef, $clear_str) = @_;
	@clear  = split(/ /, $clear_str);
	$buffer = weechat::buffer_search("irc", "twitch.$clear[3]");
	if (substr($clear[0], 1, 12) eq"ban-duration") {
		weechat::print($buffer, weechat::color("magenta") . "*\t" . weechat::color("bold") . weechat::color("magenta") . substr($clear[4], 1) . " a été expulsé du salon." . weechat::color("-bold"));
	}
	else {
		weechat::print($buffer, weechat::color("magenta") . "*\t" . weechat::color("bold") . weechat::color("magenta") . substr($clear[4], 1) . " a été banni du salon." . weechat::color("-bold"));
	}
	return "";
}

#Ignore les commandes USERSTATE et ROOMSTATE envoyé par twitch
sub userroomstate_cb {
	return "";
}

#Déchargement de script
sub unload {
	return weechat::WEECHAT_RC_OK;
}
