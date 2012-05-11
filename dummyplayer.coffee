###
DummyPlayer Bot
  Just a basic bot for providing a debug interface

(c) 2012, Schiffchen Team <schiffchen@dsx.cc>
###

#-----------------------------------------------------------------------------#

xmpp = require('node-xmpp')

# I feel like I have to expand the String object because
# I like to have a startsWith()
if typeof String.prototype.startsWith != 'function'
  String.prototype.startsWith = (str) ->
    this.indexOf(str) == 0

#-----------------------------------------------------------------------------#

class BasicBot
  constructor: (@xmppClient) ->
  
  say: (to, message) ->
    @xmppClient.send new xmpp.Element('message', {'type': 'chat', 'to': to})
      .c('body').t(message)
      
#-----------------------------------------------------------------------------#

class DummyPlayer extends BasicBot
  showReadyStatus: ->
    @xmppClient.send new xmpp.Element('presence', {})
      .c('show').t('chat').up()
      .c('status').t('The dummyplayer is ready!').up()
      .c('priority').t('0')

  handleStanza: (stanza) ->
    if stanza.attrs.type != 'error'
      switch stanza.name
        when 'message'
          if stanza.type == 'chat'
            @processCommand(stanza)

  processCommand: (stanza) ->
    body = stanza.getChild('body')
    if body
      message = body.getText()
      if message.startsWith('help')
        @help(stanza.from)
      else if message.startsWith('ping matchmaker')
        @say('matchmaker@battleship.me', 'ping')
      else if message.startsWith('queue me')
        @queueMe()
      else
        @say(stanza.from, 'I am so sorry, I did not understand you! :-(')
  
  help: (to) ->
    @say(to, """You wanna help? Here you are:
      help - Shows this message
      ping matchmaker - Sends a chat message to the matchmaker""")
      
  queueMe: ->
    @xmppClient.send new xmpp.Element('message', {'type': 'normal', 'to': 'matchmaker@battleship.me'})
      .c('battleship', {'xmlns': 'http://battleship.me/xmlns/'})
      .c('queueing', {'action': 'request'})
    
#-----------------------------------------------------------------------------#

client = new xmpp.Client({jid: process.env.PLAYER_JID, password: process.env.PLAYER_PASSWORD})
dp = new DummyPlayer(client)

#-----------------------------------------------------------------------------#

client.on 'online', ->
  dp.showReadyStatus()

client.on 'stanza', (stanza) -> 
  dp.handleStanza(stanza)  
