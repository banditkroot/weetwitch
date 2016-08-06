# weetwitch
Launch [Twitch.tv](http://twitch.tv) stream in Weechat with livestreamer. You can check your followed stream from [Twitch.tv](http://twitch.tv). You can also check information of Twitch's users. The script ignore the ROOMSTATE and USERSTATE command send by the server, if twitch/commands capabilities are activated.

##Dependencies :
* [Livestreamer](http://livestreamer.tanuki.se/)
* Perl
   * libjson-perl
   * libtry-tiny-perl
* curl

##IRC Server :
* Twitch.tv : irc.twitch.tv/6667

##Script commands :
    /stream
Watch the stream in the current channel.

    /whostream
Checking online stream for the followed channel, you need to enter your [Twitch token](http://www.twitchapps.com/tmi) at line 6, the one you used with livestreamer should work.

    /whotwitch twitchusername
Print Twitch's user information.

    /viewers
Print the numbers of viewers of the current channel if it's live 
