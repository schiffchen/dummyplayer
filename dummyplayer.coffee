###
DummyPlayer Bot
  Just a basic bot for providing a debug interface

(c) 2012, Schiffchen Team <schiffchen@dsx.cc>

This server is designed to run on heroku. Therefore, we are using environment
variables to allow our deploying machine to set up the settings dynamically.
###

#-----------------------------------------------------------------------------#

xmpp = require('node-xmpp')

# Just a little helper to determinate if a string
# starts with something or not
if typeof String.prototype.startsWith != 'function'
  String.prototype.startsWith = (str) ->
    this.indexOf(str) == 0

# timestamp calculation in JS is ugly, so
# we need that little helper method here.
now_ts = ->
  Math.round((new Date()).getTime() / 1000)

#-----------------------------------------------------------------------------#

###
  BasicBot
  
  A very basic bot class. Simply does nothing but saying something
  to someone
###
class BasicBot
  constructor: (@xmppClient) ->
  
  ###
    Say
    
    A method to send someone a message!
    
    Params:
      - to [String] The recipent
      - message [String] The message
  ###
  say: (to, message) ->
    @xmppClient.send new xmpp.Element('message', {'type': 'chat', 'to': to})
      .c('body').t(message)
      
#-----------------------------------------------------------------------------#

###
  DummyPlayer
  
  Our dummyplayer class handling everything
  
  Extends BasicBot
###
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
      else if message.startsWith('send statistic')
        @dummyStatistics()
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
      queue id - Shows the current queue id
      send statistics - Sends a dummy result for statistics testing""")
  
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
  
  ###
    dummyStatistics
    
    Send dummy statistics to the matchmaker
  ###
  dummyStatistics: ->
    @xmppClient.send new xmpp.Element('message', {'type': 'normal', 'to': 'matchmaker@battleship.me'})
      .c('battleship', {'xmlns': 'http://battleship.me/xmlns/'})
      .c('result', {'mid': '12345', 'winner': 'dummyplayer@battleship.me/debug'})
      # <result mid="[match id]" winner="[winners jid]" />
    
    
#-----------------------------------------------------------------------------#

client = new xmpp.Client({jid: process.env.PLAYER_JID, password: process.env.PLAYER_PASSWORD})
dp = new DummyPlayer(client)

# This array is used as some kind of cache between the processes. We
# have to do it that way because node js is non-blocking...
globarr = new Array()

#-----------------------------------------------------------------------------#

client.on 'online', ->
  dp.showReadyStatus()

client.on 'stanza', (stanza) -> 
  dp.handleStanza(stanza)  
