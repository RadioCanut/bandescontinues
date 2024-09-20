#!/usr/bin/liquidsoap

# Live connection
# url               : http://stream.monurl.org:8000
# point de montage  : pointmontage
# login/mdp         : login:mdp

# Constantes
# Répertoire de musique principal
LOG_FILE            = "/directory/bandescontinues.log"
MUSIC_DIRECTORY     = "/directory/musique/years/"
NEW_DIRECTORY       = "/directory/musique/new"
JINGLES_DIRECTORY   = "/directory/musique/jingles"
INFOS_DIRECTORY     = "/directory/musique/infos"
NEUF_DIRECTORY      = "/directory/musique/prog_distante/9h"
ONZE_DIRECTORY      = "/directory/musique/prog_distante/11h"
DIXHUIT_DIRECTORY   = "/directory/musique/prog_distante/18h"


# Fichier de log
set("log.file.path", LOG_FILE)
set("log.level",3)

# Input live direct
set("harbor.bind_addrs",["0.0.0.0"])
set("server.telnet",true)

# Construction de la liste des répertoires
# @param music_uri String directory
def directory_list(music_uri) =
    # directory list sort by desc 
    dir_list = 
        list.sort(
            fun(x,y)-> if x>y then -1 else 1 end, 
            file.ls(absolute=true,recursive=false, music_uri))

    dir_list
end

# Initialisation de la playlist 
# @param music_uri String directory
def construct_playlist(music_uri)
    playlists = ref []
    dir_list = directory_list(music_uri)
    index = ref list.length(dir_list)
    weights_years = ref []
    
    def add_pl(x)
        playlists := list.add ( playlist(reload_mode="watch", mode="random", x), !playlists)
        weights_years := list.append(!weights_years,[!index])
        index := !index - 1
    end

    # Une entrée par année
    list.iter(fun(x) -> add_pl(x), dir_list)

    # Return playlist initialised
    playlists := list.rev(!playlists)
    random(weights = !weights_years, !playlists)
end

# Musique (repertoire ou se trouve les musiques)
def start_bandes_continues() =
    
    # Playlist initiale : toutes les années
    playslist_init = construct_playlist(MUSIC_DIRECTORY)

    # Ajout des morceaux récents toutes les 7 fichiers joués
    recents = playlist(reload_mode="watch", mode="randomize", NEW_DIRECTORY)
    playslist_full = rotate(weights = [1,7],[recents, playslist_init])

    # Ajout des jingles toutes les 4 fichiers joués
    jingles = playlist(reload_mode="watch", mode="random", JINGLES_DIRECTORY)
    playslist_full = rotate(weights = [1,4],[jingles, playslist_full])

    # Canut Infos
    #canut_infos = single(CANUTINFOS)
    canut_infos = playlist(reload_mode="watch" , loop=true,mode="normal", INFOS_DIRECTORY)	
    
    # 9h
    neuf_h = playlist(reload_mode="watch", loop=true, mode="normal", NEUF_DIRECTORY)
    
    # 11h
    onze_h = playlist(reload_mode="watch", loop=true, mode="normal", ONZE_DIRECTORY)
    
    # 18h
    dixhuit_h = playlist(reload_mode="watch", loop=true, mode="normal", DIXHUIT_DIRECTORY)
    
    # Ajout des infos matinales à 8h du lundi au vendredi
    playslist_full = fallback(track_sensitive = false, [switch([({(1w or 2w or 3w or 4w or 5w or 6w) and (08h00)},canut_infos)]), playslist_full])
    playslist_full = fallback(track_sensitive = false, [switch([({(1w or 2w or 3w or 4w or 5w or 6w or 7w) and (09h00-09h10)},neuf_h)]), playslist_full])
    playslist_full = fallback(track_sensitive = false, [switch([({5w and (11h00-11h10)},onze_h)]), playslist_full])
    playslist_full = fallback(track_sensitive = false, [switch([({5w and (18h00-18h10)},dixhuit_h)]), playslist_full])
    # Live pour les diff
    live = audio_to_stereo(input.harbor("pointmontage", port=xxxx, user="login", password="mdp"))
    live2 = audio_to_stereo(input.harbor("autrepointmontage", port=yyyy, user="login", password="mdp"))

    mixed = add([live,live2])

    radio = nrj(fallback(track_sensitive = false, [mixed, playslist_full]))

    # Output pour le son radio
    output.alsa(id="liquidsoap", device="plughw:1,0", bufferize=true, mksafe(radio))

    # Information de diffusion
    output.icecast(%mp3(bitrate=192),
    host = "127.0.0.1", port = 8000,
    name = "Radio Canut - Bandes Continues", description = "La plus rebelle", genre = "Tout et tout", url = "https://radiocanut.org",
    password = "mdpadminicecast",
    mount = "pointmontage", fallible=true, radio)

end

start_bandes_continues()

