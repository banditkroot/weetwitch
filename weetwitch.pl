use strict;
use warnings;
use utf8;
use JSON;
use Try::Tiny;
use Date::Parse;
use Date::Format;
use Date::Language;

my $sc_name = "WeeTwitch";
my $version = "0.8.4";
my $lang = Date::Language->new('French');
my ($token, $clientid, $channel, $server, $json, $decode, $fdecode, $user_id, $player, $couleur);
my ($game, $user, $mature, $follow, $buffer, $partner, $cb_str, $w_str, $incr, $reason, $stream_arg, $gpchat, $time);
my @liste;
my (%tags, %badge);

weechat::register($sc_name, "BOUTARD Florent <bandit.kroot\@gmail.com", $version, "GPL3", "Lance les streams Twitch.tv", "unload", "");
weechat::hook_command("whostream", "Juste taper /whostream.", "", "", "", "who_stream", "");
weechat::hook_command("whotwitch", "Taper /whotwitch et le nom d\'un utilisateur.", "", "", "", "whotwitch", "");
weechat::hook_command("stream", "Juste taper /stream dans le channel désiré.", "", "", "", "stream", "");
weechat::hook_command("viewers", "Juste taper /viewers.", "", "", "", "viewer", "");
weechat::hook_command("follow", "Juste taper /follow.", "", "", "", "follow", "");
weechat::hook_command("unfollow", "Juste taper /unfollow.", "", "", "", "unfollow", "");
weechat::hook_command("groupchat", "Juste taper /groupchat.", "", "", "", "groupchat", "");
weechat::hook_modifier("irc_in_WHISPER", "whisper_cb", "");
weechat::hook_modifier("irc_out_PRIVMSG", "privmsg_out_cb", "");
weechat::hook_modifier("irc_in2_PRIVMSG", "privmsg_in_cb", "");
weechat::hook_modifier("irc_in_USERSTATE", "ignore_cb", "");
weechat::hook_modifier("irc_in_ROOMSTATE", "roomstate_cb", "");
weechat::hook_modifier("irc_in_HOSTTARGET", "ignore_cb", "");
weechat::hook_modifier("irc_in_USERNOTICE", "usernotice_cb", "");
weechat::hook_modifier("irc_in_CLEARCHAT", "clearchat_cb", "");

my $file = weechat::info_get('weechat_dir', '') . "/weetwitch.json";
try {
	open(FICHIER, "<", $file) or die weechat::print(weechat::current_buffer(), "*\tImpossible d'ouvrir le fichier de configuration.");
		@liste = <FICHIER>;
	close(FICHIER);
	$json = join("", @liste);
	$fdecode = decode_json($json);
	$token = $fdecode->{'token'};
	$clientid = $fdecode->{'clientid'};
	$player = $fdecode->{'player'};
}
catch {
	weechat::print(weechat::current_buffer(), "*\tPas de token et client id Twitch trouvé.");
};

userid(weechat::config_string(weechat::config_get("irc.server.twitch.nicks")));
my $twitch_un = $user_id;

#Groupchat
sub groupchat {
	buffer();
	try {
		$json = `curl -s -X GET http://chatdepot.twitch.tv/room_memberships?oauth_token=$token`;
		$decode = decode_json($json);
		$gpchat = $decode->{'memberships'};
		if (scalar(@{$gpchat}) == 0) {
			weechat::print($buffer, "Pas de chat de groupe.");
			return weechat::WEECHAT_RC_OK;
		}
		foreach my $displaygroup (@{$gpchat}) {
			weechat::command("", "/quote -server twitch JOIN #" . $displaygroup->{'room'}{'irc_channel'});
		}
	}
	catch {
		weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Impossible de récupérer les chats de groupe...");
	};
	return weechat::WEECHAT_RC_OK;
}

#Vérification des chat de groupe
sub checkgroup {
	foreach my $displaygpchat (@{$gpchat}) {
		if ($channel eq $displaygpchat->{'room'}{'irc_channel'}) {
			weechat::buffer_set(weechat::buffer_search("irc", "twitch.#" . $channel), "title", $displaygpchat->{'room'}{'display_name'});
			return 0;
		}
	}
	return 1;
}

#Commande /whostream
sub who_stream {
	buffer();
	try {
		$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Authorization: OAuth $token' -X GET https://api.twitch.tv/kraken/streams/followed`;
		$decode = decode_json($json);
		@liste = undef;
		$incr = 1;
		if ($decode->{'_total'} eq "0") {
			weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Pas de stream en cours...");
			return weechat::WEECHAT_RC_OK;
		}
		weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Stream en cours :");
		foreach my $displayname (@{$decode->{'streams'}}) {
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
			if ($displayname->{'stream_type'} eq "live"){
				$couleur = "gray";
			}
			else {
				$couleur = "blue";
			}
			$incr++;
			push @liste, lc($displayname->{'channel'}{'display_name'});
			weechat::print($buffer, "$partner\t" . weechat::color($couleur) . weechat::color("bold") . "$displayname->{'channel'}{'display_name'}" . weechat::color("-bold") . " stream $game $mature $displayname->{'viewers'} spectateurs.");
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
		$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/users?login=$user&api_version=5`;
		$decode = decode_json($json);
		foreach my $displayuser (@{$decode->{'users'}}) {
			$user_id = $displayuser->{'_id'};
			weechat::print("$buffer","Utilisateur\t". weechat::color("bold") . $displayuser->{'display_name'} . weechat::color("-bold"));
			weechat::print("$buffer","Type\t$displayuser->{'type'}");
			if ($decode->{'bio'}) { weechat::print("$buffer","Bio\t$displayuser->{'bio'}"); }
			timeparse($displayuser->{'created_at'});
			weechat::print("$buffer","Créé le\t$time");
			timeparse($displayuser->{'updated_at'});
			weechat::print("$buffer","Dernière MAJ\t$time");
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: $clientid'  -X GET https://api.twitch.tv/kraken/users/$user_id/follows/channels`;
			$decode = decode_json($json);
			if ($decode->{'_total'} eq "1") {
				foreach my $displayfollow (@{$decode->{'follows'}}) {
					$follow = " : " . $displayfollow->{'channel'}{'name'};
				}
			}
			else {
				$follow = "s.";
			}
			weechat::print("$buffer","Il follow\t" . $decode->{'_total'} . " personne" . $follow);
			weechat::print("$buffer","URL\thttp://twitch.tv/$user/profile");
		}
	}
	return weechat::WEECHAT_RC_OK;
}

#Gère la commande /stream
sub stream {
	$stream_arg = lc($_[2]);
	if ($stream_arg) {
		$channel = $stream_arg;
		undef $stream_arg;
		weechat::command("", "/quote -server twitch JOIN #" . $channel);
		stream_launch();
		return weechat::WEECHAT_RC_OK;
	}
	elsif (server() and not $stream_arg) {
		stream_launch();
	}
	return weechat::WEECHAT_RC_OK;
}

#Lancement d'un scream
sub stream_launch {
	buffer();
	weechat::print($buffer, "---\tLancement du stream twitch.tv/$channel...");
	weechat::hook_process("$player twitch.tv/$channel", 0, "stream_end", "");
}

#Fin de stream
sub stream_end {
	buffer();
	weechat::print($buffer, "Fin du stream.");
	return weechat::WEECHAT_RC_OK;
}

#Récupère les info sur les chaines
sub channel_info {
	userid($channel);
	buffer();
	weechat::print($buffer, "Chaîne\t" . weechat::color("bold") . "$channel");
	try {
		$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/streams?channel=$user_id`;
		$decode = decode_json($json);
		if ($decode->{'_total'} == 1) {
			foreach my $displayinfo (@{$decode->{'streams'}}) {
				weechat::buffer_set(weechat::buffer_search("irc", "twitch.#" . $channel), "title", $displayinfo->{'channel'}{'status'});
				weechat::print($buffer, "Titre\t$displayinfo->{'channel'}{'status'}");
				weechat::print($buffer, "Jeu en cours\t$displayinfo->{'game'}");
				weechat::print($buffer, "Spectateurs\t$displayinfo->{'viewers'}");
				timeparse($displayinfo->{'created_at'});
				weechat::print($buffer, "Commencé\tle $time");
				weechat::print($buffer, "Vidéo source\t$displayinfo->{'video_height'}p à $displayinfo->{'average_fps'}fps");
				weechat::print($buffer, "Délais\t$displayinfo->{'delay'}");
				weechat::print($buffer, "Langage\t$displayinfo->{'channel'}{'broadcaster_language'}");
				if ($displayinfo->{'channel'}{'mature'}) { weechat::print($buffer, "*\tStream mature"); }
				if ($displayinfo->{'channel'}{'partner'}) { weechat::print($buffer, "*\tStream partenaire"); }
				weechat::print($buffer, "Abonnés\t$displayinfo->{'channel'}{'followers'}");
			}
		}
		else {
			weechat::print($buffer, "*\t" . weechat::color("bold") . "Pas de stream en cours...");
		}
	}
	catch {
		weechat::print($buffer, "Impossible de récupérer le topic.");
	};
}

#Affiche les viewers
sub viewer {
	if (server()) {
		try {
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/streams?channel=$user_id`;
			$decode = decode_json($json);
			if ($decode->{'_total'} == 1) {
				foreach my $displayinfo (@{$decode->{'streams'}}) {
					weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "Actuellement $displayinfo->{'viewers'} spectateurs.");
				}
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
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Authorization: OAuth $token' -X PUT https://api.twitch.tv/kraken/users/$twitch_un/follows/channels/$user_id`;
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
			$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Authorization: OAuth $token' -X DELETE https://api.twitch.tv/kraken/users/$twitch_un/follows/channels/$user_id`;
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
			stream(0,0,$liste[$string]); #Placer en argument 2 à cause de /stream username
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
		userid($channel);
		return 1;
	}
	else {
		weechat::print(weechat::current_buffer(), "*\tServeur et/ou channel non valide.");
		return 0;
	}
}

#Récupération du userid
sub userid{
	$user = $_[0];
	foreach my $displayid (@{$fdecode->{'id'}}) {
		if ($user eq $displayid->{'name'}) {
			$user_id = $displayid->{'userid'};
			return;
		}
	}
	$json = `curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: $clientid' -X GET https://api.twitch.tv/kraken/users?login=$user&api_version=5`;
	$decode = decode_json($json);
	foreach my $displayuser (@{$decode->{'users'}}) {
		$user_id = $displayuser->{'_id'};
	}
	$fdecode->{'id'}[scalar(@{$fdecode->{'id'}})] = {"name", $user, "userid", $user_id};
	open(FICHADD, ">:encoding(UTF-8)", $file);
		print FICHADD JSON->new->indent->space_after->encode($fdecode);
	close(FICHADD);
	buffer();
	weechat::print($buffer, "---\t" . weechat::color("blue") ."ID utilisateur ajouté au fichier $file");
}

#Affiche les message d'expulsion de twitch
sub clearchat_cb {
	(undef, undef, undef, $cb_str) = @_;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	$buffer = weechat::buffer_search("irc", "twitch." . $cb_str->{"channel"});
	%tags = split(/[;=]/, $cb_str->{"tags"});
	if ($tags{"ban-reason"}) {
		$reason = "(" . join(" ", split(/[\\]s/, $tags{"ban-reason"})) . ")";
	}
	else {
		$reason = "(Pas de raison.)";
	}
	if (exists($tags{"ban-duration"})) {
		return ":" . $cb_str->{"text"} . " NOTICE " . $cb_str->{"channel"} . " :a été expulsé du salon pour " . $tags{"ban-duration"} . "s. $reason";
	}
	elsif (not exists($tags{"ban-duration"}) and exists($tags{"ban-reason"})) {
		return ":" . $cb_str->{"text"} . " NOTICE " . $cb_str->{"channel"} . " :a été banni du salon. $reason";
	}
	return "";
}

#Affiche les whipers de twitch
sub whisper_cb {
	(undef, undef, undef, $cb_str) = @_;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	return ":" . $cb_str->{"host"} . " PRIVMSG " . $cb_str->{"arguments"};
}

#Pour envoyer les message privé
sub privmsg_out_cb {
	(undef, undef, $server, $cb_str) = @_;
	if ($server ne "twitch") { return $cb_str; }
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	if ($cb_str->{"channel"} =~ "#") {
		return "PRIVMSG " . $cb_str->{"channel"} . " :" . $cb_str->{"text"};
	}
	else {
		return "PRIVMSG jtv :.w " . $cb_str->{"nick"} . " " . $cb_str->{"text"};
	}
}

#Gestion des badges
sub privmsg_in_cb {
	(undef, undef, $server, $cb_str) = @_;
	if ($server ne "twitch") { return $cb_str; }
	$w_str = $cb_str;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	if (substr($cb_str->{"channel"}, 0, 1) ne "#") { return $w_str; }
	if (substr($cb_str->{"tags"}, -1) eq "=") {
		%tags = split(/[;=]/, $cb_str->{"tags"} . " "); #ajouter de " " car user-type n'est pas systématiquement envoyé
	}
	else {
		%tags = split(/[;=]/, $cb_str->{"tags"});
	}
	if ($tags{"display-name"}) {
		$reason = $tags{"display-name"};
	}
	else {
		$reason = $cb_str->{"nick"};
	}
	if ($tags{"badges"}) {
		%badge = split(/[\/,]/, $tags{"badges"});
		if (exists($badge{"subscriber"})) { $reason = weechat::color("bold") . $reason; }
		if (exists($badge{"turbo"})) { $reason = weechat::color("magenta") . "+" . $reason; }
		if (exists($badge{"premium"})) { $reason = weechat::color("cyan") . "+" . $reason; }
		if (exists($badge{"partner"})) { $reason = weechat::color("brown") . "✓" . $reason; }
		if (exists($badge{"moderator"})) { $reason = weechat::color("red") . "@" . $reason; }
		if (exists($badge{"global_mod"})) { $reason = weechat::color("gray,red") . "@" . $reason; }
		if (exists($badge{"admin"})) { $reason = weechat::color("white,red") . "%" . $reason; }
		if (exists($badge{"staff"})) { $reason = weechat::color("white,magenta") . "&" . $reason; }
	}
	$reason =  weechat::color("gray") . $reason;
	return ":$reason PRIVMSG " . $cb_str->{"arguments"};
}

#Subscription
sub usernotice_cb {
	(undef, undef, undef, $cb_str) = @_;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	$buffer = weechat::buffer_search("irc", "twitch." . $cb_str->{"channel"});
	if (substr($cb_str->{"tags"}, -1) eq "=") {
		%tags = split(/[;=]/, $cb_str->{"tags"} . " "); #ajouter de " " car user-type n'est pas systématiquement envoyé
	}
	else {
		%tags = split(/[;=]/, $cb_str->{"tags"});
	}
	$reason = join(" ", split(/[\\]s/, $tags{"system-msg"}));
	if ($cb_str->{"text"}) { $reason = $reason . " Message : " . $cb_str->{"text"}; }
	weechat::print($buffer, weechat::color("green") . "*\t" . weechat::color("green") . $reason);
	return "";
}

#Mode des salons
sub roomstate_cb {
	(undef, undef, $server, $cb_str) = @_;
	if ($server ne "twitch") { return $cb_str; }
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	$channel = substr($cb_str->{"channel"},1);
	if (checkgroup()) { channel_info(); }
	if (substr($cb_str->{"tags"}, -1) ne "=") {
		%tags = split(/[;=]/, $cb_str->{"tags"});
		if (exists($tags{"broadcaster-lang"})) {
			undef $reason;
			if ($tags{"emote-only"}) { $reason = "emote-only "; }
			if ($tags{"followers-only"}) { $reason = $reason . "followers-only "; }
			if ($tags{"r9k"}) { $reason = $reason . "r9k "; }
			if ($tags{"slow"}) { $reason = $reason . "slow " . $tags{"slow"} . "s "; }
			if ($tags{"subs-only"}) { $reason = $reason . "subs-only"; }
			if ($reason) { return ":#" . $channel . " NOTICE #" . $channel . " :Mode : $reason"; }
		}
	}
	return "";
}

#formatage des dates
sub timeparse {
	$time = str2time(@_);
	$time = $lang->time2str("%A %e %B %Y à %X", $time);
}

#Ignore les commandes USERSTATE et HOSTARGET envoyé par twitch
sub ignore_cb {
	return "";
}

#Déchargement de script
sub unload {
	return weechat::WEECHAT_RC_OK;
}
