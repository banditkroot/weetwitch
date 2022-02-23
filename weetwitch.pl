use strict;
use warnings;
use utf8;
use JSON;
use Try::Tiny;
use Date::Parse;
use Date::Format;
use Date::Language;

my $sc_name = "WeeTwitch";
my $version = "0.11.0";
my $lang = Date::Language->new('French');
my ($token, $clientid, $channel, $server, $json, $decode, $fdecode, $user_id, $player, $couleur);
my ($game, $user, $mature, $follow, $buffer, $partner, $cb_str, $w_str, $incr, $reason, $stream_arg, $gpchat, $time);
my @liste;
my (%tags, %badge);

weechat::register($sc_name, "BOUTARD Florent <bandit.kroot\@gmail.com", $version, "GPL3", "Lance les streams Twitch.tv", "unload", "");
weechat::hook_command("whostream", "Juste taper /whostream.", "", "", "", "who_stream", "");
weechat::hook_command("whotwitch", "Taper /whotwitch et le nom d\'un utilisateur.", "", "", "", "whotwitch", "");
weechat::hook_command("stream", "Juste taper /stream dans le channel désiré.", "", "", "", "stream", "");
weechat::hook_command("subcheck", "Juste taper /subcheck dans le channel désiré.", "", "", "", "subcheck", "");
weechat::hook_command("viewers", "Juste taper /viewers.", "", "", "", "viewer", "");
weechat::hook_modifier("irc_in_WHISPER", "whisper_cb", "");
weechat::hook_modifier("irc_out_PRIVMSG", "privmsg_out_cb", "");
weechat::hook_modifier("irc_in2_PRIVMSG", "privmsg_in_cb", "");
weechat::hook_modifier("irc_in2_NOTICE", "notice_in_cb", "");
weechat::hook_modifier("irc_in_USERSTATE", "ignore_cb", "");
weechat::hook_modifier("irc_in_ROOMSTATE", "roomstate_cb", "");
weechat::hook_modifier("irc_in_HOSTTARGET", "ignore_cb", "");
weechat::hook_modifier("irc_in_USERNOTICE", "usernotice_cb", "");
weechat::hook_modifier("irc_in_CLEARCHAT", "clearchat_cb", "");
weechat::hook_modifier("irc_in_CLEARMSG", "ignore_cb", "");

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

#Commande /whostream
sub who_stream {
	buffer();
	try {
		$json = `curl -s -X GET 'https://api.twitch.tv/helix/streams/followed?user_id=$twitch_un' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
		weechat::print(weechat::current_buffer(), "curl -s -X GET 'https://api.twitch.tv/helix/streams/followed?user_id=$twitch_un' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'");
		$decode = decode_json($json);
		@liste = undef;
		$incr = 1;
		weechat::print($buffer, "---\t" . weechat::color("red") . weechat::color("bold") . "Stream en cours :");
		foreach my $displayname (@{$decode->{'data'}}) {
			if ($displayname->{'game_name'}) {
				$game = "du " . weechat::color("bold") . $displayname->{'game_name'} . weechat::color("-bold");
			}
			else {
				$game = "aucun jeu";
			}
			if ($displayname->{'type'} eq "live"){
				$couleur = "default";
			}
			else {
				$couleur = "blue";
			}
			$incr++;
			push @liste, lc($displayname->{'user_name'});
			weechat::print($buffer, "\t" . weechat::color($couleur) . weechat::color("bold") . "$displayname->{'user_name'}" . weechat::color("-bold") . " stream $game avec $displayname->{'viewer_count'} spectateurs.");
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
		$json = `curl -s -X GET 'https://api.twitch.tv/helix/users?login=$user' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
		$decode = decode_json($json);
		foreach my $displayuser (@{$decode->{'data'}}) {
			$user_id = $displayuser->{'id'};
			weechat::print("$buffer","Utilisateur\t". weechat::color("bold") . $displayuser->{'display_name'} . weechat::color("-bold"));
			if ($displayuser->{'type'}) { weechat::print("$buffer","Type\t$displayuser->{'type'}"); }
			if ($displayuser->{'description'}) { weechat::print("$buffer","Bio\t$displayuser->{'description'}"); }
			timeparse($displayuser->{'created_at'});
			weechat::print("$buffer","Créé le\t$time");
			$json = `curl -s -X GET 'https://api.twitch.tv/helix/users/follows?from_id=$user_id' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
			$decode = decode_json($json);
			if ($decode->{'total'} eq "1") {
				foreach my $displayfollow (@{$decode->{'data'}}) {
					$follow = " : " . $displayfollow->{'to_name'};
				}
			}
			else {
				$follow = "s.";
			}
			weechat::print("$buffer","Il follow\t" . $decode->{'total'} . " personne" . $follow);
			weechat::print("$buffer","URL\thttp://twitch.tv/$user/profile");
		}
	}
	return weechat::WEECHAT_RC_OK;
}

#Vérifie si l'utilisateur est sub à la chaine
sub subcheck {
	if (server()) {
		try {
			$json = `curl -s -X GET 'https://api.twitch.tv/helix/subscriptions/user?broadcaster_id=$user_id&user_id=$twitch_un' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
			$decode = decode_json($json);
			if ($decode->{'error'}) {
				weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "Vous n'êtes pas abonné.");
			}
			else {
				foreach my $displaytier (@{$decode->{'data'}}) {
					weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "Vous êtes abonné tier " . $displaytier->{'tier'} / 1000 . ".");
				}
			}
		}
		catch {
			weechat::print(weechat::current_buffer(), "*\tImpossible de vérifier l\'abonnement.");
		};
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
		$json = `curl -s -X GET 'https://api.twitch.tv/helix/streams?user_id=$user_id' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
		$decode = decode_json($json);
		if (@{$decode->{'data'}}) {
			foreach my $decodechan (@{$decode->{'data'}}) {
				weechat::buffer_set(weechat::buffer_search("irc", "twitch.#" . $channel), "title", $decodechan->{'title'});
				weechat::print($buffer, "Titre\t$decodechan->{'title'}");
				weechat::print($buffer, "Jeu en cours\t$decodechan->{'game_name'}");
				weechat::print($buffer, "Spectateurs\t$decodechan->{'viewer_count'}");
				weechat::print($buffer, "Type\t$decodechan->{'type'}");
				timeparse($decodechan->{'started_at'});
				weechat::print($buffer, "Commencé\tle $time");
				weechat::print($buffer, "Langage\t$decodechan->{'language'}");
				if ($decodechan->{'is_mature'}) { weechat::print($buffer, "*\tStream mature"); }
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
			$json = `curl -s -X GET 'https://api.twitch.tv/helix/streams?user_id=$user_id' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
			$decode = decode_json($json);
			if (@{$decode->{'data'}}) {
				foreach my $decodeview (@{$decode->{'data'}}) {
					weechat::print(weechat::current_buffer(), "*\t" . weechat::color("magenta") . "Actuellement $decodeview->{'viewer_count'} spectateurs.");
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
	$json = `curl -s -X GET 'https://api.twitch.tv/helix/users?login=$user' -H 'Authorization: Bearer $token' -H 'Client-Id: $clientid'`;
	$decode = decode_json($json);
	foreach my $displayuser (@{$decode->{'data'}}) {
		$user_id = $displayuser->{'id'};
	}
	$fdecode->{'id'}[scalar(@{$fdecode->{'id'}})] = {"name", $user, "userid", $user_id};
	open(FICHADD, ">:encoding(UTF-8)", $file);
		print FICHADD JSON->new->indent->space_after->encode($fdecode);
	close(FICHADD);
	buffer();
	weechat::print($buffer, "---\t" . weechat::color("blue") ."ID utilisateur ajouté au fichier $file");
}

#Affiche les messages d'expulsion de twitch
sub clearchat_cb {
	(undef, undef, undef, $cb_str) = @_;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	%tags = split(/[;=]/, $cb_str->{'tags'});
	if (exists($tags{'ban-duration'})) {
		return ":" . $cb_str->{'text'} . " NOTICE " . $cb_str->{'channel'} . " :a été expulsé du salon pour " . $tags{'ban-duration'} . "s.";
	}
	else {
		return ":" . $cb_str->{'text'} . " NOTICE " . $cb_str->{'channel'} . " :a été banni du salon.";
	}
}

#Affiche les whispers de twitch
sub whisper_cb {
	(undef, undef, undef, $cb_str) = @_;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	return ":" . $cb_str->{'host'} . " PRIVMSG " . $cb_str->{'arguments'};
}

#Pour envoyer les message privé
sub privmsg_out_cb {
	(undef, undef, $server, $cb_str) = @_;
	if ($server ne "twitch") { return $cb_str; }
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	if ($cb_str->{'channel'} =~ "#") {
		return "PRIVMSG " . $cb_str->{'channel'} . " :" . $cb_str->{'text'};
	}
	else {
		return "PRIVMSG jtv :.w " . $cb_str->{'nick'} . " " . $cb_str->{'text'};
	}
}

#Gestion des badges
sub privmsg_in_cb {
	(undef, undef, $server, $cb_str) = @_;
	no utf8;
	if ($server ne "twitch") { return $cb_str; }
	$w_str = $cb_str;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	if (substr($cb_str->{'channel'}, 0, 1) ne "#") { return $w_str; }
	if ($cb_str->{'nick'} eq weechat::config_string(weechat::config_get("irc.server.twitch.nicks"))) { return ""; } #utilisé pour les salles privées, twitch renvoi les message de l'utilisateur
	$reason = $cb_str->{'nick'};
	my @taglist = split(/[;]/, $cb_str->{'tags'});
	if (substr($taglist[1], -1) ne "=") {
		%tags = split(/[=]/, $taglist[1]);
		%badge = split(/[\/,]/, $tags{"badges"});
		if (exists($badge{'subscriber'})) { $reason = weechat::color("bold") . $reason; }
		if (exists($badge{'turbo'})) { $reason = weechat::color("125") . "+" . $reason; }
		if (exists($badge{'premium'})) { $reason = weechat::color("37") . "+" . $reason; }
		if (exists($badge{'partner'})) { $reason = weechat::color("136") . "✓" . $reason; }
		if (exists($badge{'moderator'})) { $reason = weechat::color("166") . "@" . $reason; }
		if (exists($badge{'global_mod'})) { $reason = weechat::color("gray,red") . "@" . $reason; }
		if (exists($badge{'admin'})) { $reason = weechat::color("white,red") . "%" . $reason; }
		if (exists($badge{'staff'})) { $reason = weechat::color("white,magenta") . "&" . $reason; }
	}
	$reason =  weechat::color("245") . $reason;
	return ":$reason PRIVMSG " . $cb_str->{'arguments'};
}

#Modification des notices
sub notice_in_cb {
	(undef, undef, $server, $cb_str) = @_;
	no utf8;
	if ($server ne "twitch") { return $cb_str; }
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	if ($cb_str->{'nick'} eq "sub" or $cb_str->{'nick'} eq "resub" or $cb_str->{'nick'} eq "subgift") {
		$couleur = "green";
	}
	elsif ($cb_str->{'nick'} eq "raid") {
		$couleur = "red";
	}
	elsif ($cb_str->{'nick'} eq "ritual") {
		$couleur = "blue";
	}
	else {
		$couleur = "default";
	}
	return ":" . weechat::color($couleur) . $cb_str->{'nick'} . " NOTICE " . $cb_str->{'channel'} . " :" . weechat::color($couleur) . $cb_str->{'text'};
}

#Subscription raid ritual
sub usernotice_cb {
	(undef, undef, undef, $cb_str) = @_;
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	if (substr($cb_str->{'tags'}, -1) eq "=") {
		%tags = split(/[;=]/, $cb_str->{'tags'} . " "); #ajouter de " " car user-type n'est pas systématiquement envoyé
	}
	else {
		%tags = split(/[;=]/, $cb_str->{'tags'});
	}
	$reason = join(" ", split(/[\\]s/, $tags{'system-msg'}));
	if ($cb_str->{'text'}) { $reason = $reason . " Message : " . $cb_str->{'text'}; }
	return ":" . $tags{'msg-id'} . " NOTICE " . $cb_str->{'channel'} . " :$reason";
}

#Mode des salons
sub roomstate_cb {
	(undef, undef, $server, $cb_str) = @_;
	if ($server ne "twitch") { return $cb_str; }
	$cb_str = weechat::info_get_hashtable("irc_message_parse", {"message" => $cb_str});
	$channel = substr($cb_str->{'channel'},1);
	channel_info();
	if (substr($cb_str->{'tags'}, -1) ne "=") {
		%tags = split(/[;=]/, $cb_str->{'tags'});
		if (exists($tags{'broadcaster-lang'})) {
			$reason = "";
			if ($tags{'emote-only'}) { $reason = "emote-only "; }
			if ($tags{'followers-only'}) { $reason = $reason . "followers-only "; }
			if ($tags{'r9k'}) { $reason = $reason . "r9k "; }
			if ($tags{'slow'}) { $reason = $reason . "slow " . $tags{'slow'} . "s "; }
			if ($tags{'subs-only'}) { $reason = $reason . "subs-only "; }
			if ($tags{'rituals'}) { $reason = $reason . "rituals"; }
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

#Ignore les commandes CLEARMSG, USERSTATE et HOSTARGET envoyé par twitch
sub ignore_cb {
	return "";
}

#Déchargement de script
sub unload {
	return weechat::WEECHAT_RC_OK;
}
