# weetwitch
Lance les streams de [Twitch.tv](http://twitch.tv) dans Weechat avec livestreamer. Vous pouvez vérifier les personnes que vous suivez sur [Twitch.tv](http://twitch.tv). Il y a aussi la possibilité de récupérer des informations sur les utilisateurs. Le script ignore les commandes ROOMSTATE et USERSTATE envoyées par le serveur, si les capacités twitch/commands sont activées, la commande HOSTARGET est automatiquement indiquée en notice. Les script gère les whispers et les messages privés, il indique aussi quand des personnes sont expulsées/bannies d'un salon, ainsi que les subscribes.

##Dépendances :
* [Livestreamer](http://livestreamer.tanuki.se/)
* Perl
   * libjson-perl
   * libtry-tiny-perl
   * libtimedate-perl
* curl

##Serveur IRC :
* Twitch.tv : irc.twitch.tv/6667
* Twitch.tv : irc.twitch.tv/6697 pour le SSL

##Avant de commencer :
Il est nécessaire [d'enregistrer une application sur l'API de Twitch](https://www.twitch.tv/kraken/oauth2/clients/new), pour obtenir un client-id et un  Twitch token, à entrer dans le fichier `weetwitch.json`. Le script à besoin des [scopes](https://github.com/justintv/Twitch-API/blob/master/authentication.md#scope) `user_read`, `chat_login` et `user_follows_edit`. Le script perl doit être copié dans le dossier `~/.weechat/perl/autoload` et le fichier json dans le dossier `~/.weechat`.

##Commandes du script :
    /stream
Regarder le stream du salon en cours.

    /whostream
Vérifier les sctreams suivit en cours.

    /whotwitch twitchusername
Affiche les informations d'un utilisateur Twitch.

    /viewers
Affiche le nombre de spectateurs d'un stream en cours.

    /follow
Suivre la chaine du salon courant.

    /unfollow
Ne plus suivre la chaine du salon courant.

    /groupchat
Rejoins tous les chats de groupes de l'utilisateur.

##Joindre un salon et lancer le stream automatiquement :
Après la commande `whostream`, il suffit d'entrer le numéro d'un stream afficher pour joindre le salon et que le stream se lance automatiquement.

-----
J'ai décidé de faire un fichier de configuration en json pour enregister les user-id utilisés par le script, les user-id sont devenus obligatoire pour intéragir avec l'APIv5, cela permettra sur la longueur de réduir le nombre de requêtes faites à l'API et donc d'accélerer la vitesse du script.
