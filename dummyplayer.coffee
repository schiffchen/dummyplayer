###
DummyPlayer Bot
  Just a basic bot for providing a debug interface

(c) 2012, Schiffchen Team <schiffchen@dsx.cc>

This server is designed to run on heroku. Therefore, we are using environment
variables to allow our deploying machine to set up the settings dynamically.
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
  ###
    showReadyStatus
    
    Tell everyone the dummyplayer is ready to play.
  ###
  showReadyStatus: ->
    @xmppClient.send new xmpp.Element('presence', {})
      .c('show').t('chat').up()
      .c('status').t('The dummyplayer is ready!').up()
      .c('priority').t('0')

  ###
    handleStanza
    
    General handler for all incoming stanzas
  ###
  handleStanza: (stanza) ->
    if stanza.attrs.type != 'error'
      switch stanza.name
        when 'message'
          if stanza.type == 'chat'
            @processCommand(stanza)
          else if stanza.type == 'normal'
            @processAction(stanza)

  ###
    processCommand
    
    Handler for command stanzas. Just fires the functions to do further stuff
  ###
  processCommand: (stanza) ->
    body = stanza.getChild('body')
    if body
      message = body.getText()
      if message.startsWith('help')
        @help(stanza.from)
      else if message.startsWith('ping matchmaker')
        @say('matchmaker@battleship.me', 'ping')
      else if message.startsWith('queue ping')
        @pingQueue()
      else if message.startsWith('queue me')
        @queueMe()
        globarr['queue_answer_to'] = stanza.from
      else if message.startsWith('queue id')
        @say(stanza.from, "I am queue##{globarr['queueid']}")
      else
        @say(stanza.from, 'I am so sorry, I did not understand you! :-(')
  
  ###
    processAction
    
    Handler for battleship-game related stanzas coming in
  ###
  processAction: (stanza) ->
    battleship = stanza.getChild('battleship')
    if battleship
      if queueing = battleship.getChild('queueing')
        if queueing.attrs.action == 'success'
          @say(globarr['queue_answer_to'], "I am in the queue! Queue-ID ##{queueing.attrs.id}")
          globarr['queue_answer_to'] = ''
          globarr['queueid'] = queueing.attrs.id
      
  ###
    help
    
    Just returns a little man page.
  ###    
  help: (to) ->
    @say(to, """You wanna help? Here you are:
      help - Shows this message
      ping matchmaker - Sends a chat message to the matchmaker
      queue ping - Pings the queue to keep it alive
      queue me - Ask the matchmaker to enqueue the dummyplayer
      queue id - Shows the current queue id""")
  
  ###
    pingQueue
    
    Sends a ping to to the matchmaker to keep the queue alive
  ###
  pingQueue: ->
    @xmppClient.send new xmpp.Element('message', {'type': 'normal', 'to': 'matchmaker@battleship.me'})
      .c('battleship', {'xmlns': 'http://battleship.me/xmlns/'})
      .c('queueing', {'action': 'ping', 'id': globarr['queueid']})
      
  ###
    queueMe
    
    Ask the matchmaker to enqueue me.
  ###
  queueMe: ->
    @xmppClient.send new xmpp.Element('message', {'type': 'normal', 'to': 'matchmaker@battleship.me'})
      .c('battleship', {'xmlns': 'http://battleship.me/xmlns/'})
      .c('queueing', {'action': 'request'})
    
    
#-----------------------------------------------------------------------------#

client = new xmpp.Client({jid: process.env.PLAYER_JID, password: process.env.PLAYER_PASSWORD})
dp = new DummyPlayer(client)

# global "cache", as we sometimes have to transfer stuff ignoring
# nodejs non-blocking-io
globarr = new Array()

#-----------------------------------------------------------------------------#

client.on 'online', ->
  dp.showReadyStatus()

client.on 'stanza', (stanza) -> 
  dp.handleStanza(stanza)  
