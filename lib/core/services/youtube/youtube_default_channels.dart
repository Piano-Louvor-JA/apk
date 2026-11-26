import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';

/// Casa Publicadora Brasileira: o Novo Hinário Adventista completo (hinos 1 a
/// 600+), em 6 playlists que abrem como uma lista só. Mesmos ids do desktop.
const cpbChannel = YoutubeChannel(
  id: 'cpb',
  name: 'Casa Publicadora Brasileira',
  subtitle: 'Novo Hinário Adventista',
  url: 'https://www.youtube.com/@casapublicadora',
  youtubeId: 'UCQhkLOO40bmTMeLcbspKW8A',
  merged: true,
  playlists: [
    YoutubeChannelPlaylist(
      id: 'PLAPpcKnpMfeO9Fydpl1tTKC9CRRnIMMSK',
      name: 'Novo Hinário Adventista 1 - 100',
      coverVideoId: 'FDpludwY46U',
    ),
    YoutubeChannelPlaylist(
      id: 'PLAPpcKnpMfeOsWzlaY0bXm1Q5pnQQxn_y',
      name: 'Novo Hinário Adventista 101 - 200',
      coverVideoId: 'yey65PRKnwY',
    ),
    YoutubeChannelPlaylist(
      id: 'PLAPpcKnpMfeMnCMuGcdWKVkgpi2P_sRkE',
      name: 'Novo Hinário Adventista 201 - 300',
      coverVideoId: 'kUuN3BnJnaI',
    ),
    YoutubeChannelPlaylist(
      id: 'PLAPpcKnpMfeNIrE1nk3w2OkcUdxuY6y1l',
      name: 'Novo Hinário Adventista 301 - 400',
      coverVideoId: 'X6AAFwBkfEM',
    ),
    YoutubeChannelPlaylist(
      id: 'PLAPpcKnpMfePvD6DLI-Y5TR-RVVo62s6Z',
      name: 'Novo Hinário Adventista 401 - 500',
      coverVideoId: 'Dg2XiFULn3Q',
    ),
    YoutubeChannelPlaylist(
      id: 'PLAPpcKnpMfePWEOuIu4B4F3PVljyD8DoO',
      name: 'Novo Hinário Adventista 501 - 600',
      coverVideoId: 'FlHMYuWZK0g',
    ),
  ],
);

/// Canais que já vêm no app (somente leitura), antes dos cadastrados.
const defaultYoutubeChannels = [cpbChannel];
