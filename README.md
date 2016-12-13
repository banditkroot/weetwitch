# weetwitch
Launch [Twitch.tv](http://twitch.tv) stream in Weechat with livestreamer. You can check your followed stream from [Twitch.tv](http://twitch.tv). You can also check information of Twitch's users. The script ignore the ROOMSTATE, USERSTATE, USERNOTICE and HOSTTARGET command send by the server, if twitch/commands capabilities are activated, but integrate the CLEARCHAT command.

##Dependencies :
* [Livestreamer](http://livestreamer.tanuki.se/)
* Perl
   * libjson-perl
   * libtry-tiny-perl
* curl

##IRC Server :
* Twitch.tv : irc.twitch.tv/6667

##Before starting :
You need to [register an app on Twitch API](https://www.twitch.tv/kraken/oauth2/clients/new), with this you can have a client-id and a Twitch token, enter this in the `weetwitch.json` file. The script require `user_read`, `chat_login` and `user_follows_edit` scope. The script must be copy to `~/.weechat/perl/autoload` folder and the json file to `~/.weechat` folder.

##Script commands :
    /stream
Watch the stream in the current channel.

    /whostream
Checking online stream for the followed channel.

    /whotwitch twitchusername
Print Twitch's user information.

    /viewers
Print the numbers of viewers of the current channel if it's live 

    /follow
Follow the current channel.

    /unfollow
Unfollow the current channel.

##Join channel and launching stream :
After a whostream command, you can enter the number of the channel list for joining the channel and launching the stream automatically.

-----
I decided to make a json file for the configuration and for register the client id, that they be used by the script, for reduce the number of request doing to the API server and accelerate the script execution.
