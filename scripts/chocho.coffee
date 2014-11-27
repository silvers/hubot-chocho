# Description:
#   This robot is 空調調太郎 a.k.a chocho.
#   Counting hot/cold members for recommend air-conditioner setting in office.
#
# Dependencies:
#   "lodash": "~2.4.1"
#
# Configuration:
#   None
#
# Commands:
#   hubot air hot  - Increment hot  count in room
#   hubot air cold - Increment cold count in room
#   hubot air done - Reset hot/cold count in room
#
# Author:
#   silvers

_ = require "lodash"

class Store
  key: null

  constructor: (@brain) ->

  get: (room) ->
    source = @brain.get(@key) or {}
    source[room] or []

  getValue: (room) ->
    values = @get(room)
    value  = values.length or 0
    value

  getUsers: (room) ->
    values = @get(room)
    users  = _.map values, (row) -> row.user
    users

  save: (room, value) ->
    source = @brain.get(@key) or {}
    source[room] = value
    @brain.set(@key, source)

  add: (room, user) ->
    rows  = @get(room)
    value = @getValue(room)
    rows.push { user: user }
    @save(room, rows)

  clear: (room) ->
    @save(room, [])

class ColdStore extends Store
  key: "cold_rows"

class HotStore  extends Store
  key: "hot_rows"

module.exports = (robot) ->
  store =
    cold: new ColdStore robot.brain
    hot:  new HotStore  robot.brain

  timer = null
  clear_min = 30
  gap = 2

  reset = (room) ->
    store.cold.clear(room)
    store.hot.clear(room)
    clearTimeout(timer) if timer

  message = (room, msg) ->
    hot_count  = store.hot.getValue(room)
    cold_count = store.cold.getValue(room)

    msg.send "room: #{room} => hot: #{hot_count}, cold: #{cold_count}"

    switch
      when (hot_count - cold_count) >= gap
        msg.message.user.name = _.sample store.hot.getUsers(room)
        msg.reply "Please `turn down` the air-conditioner."
      when (cold_count - hot_count) >= gap
        msg.message.user.name = _.sample store.cold.getUsers(room)
        msg.reply "Please `turn up` the air-conditioner."

    if hot_count isnt 0 or cold_count isnt 0
      # reset after 'clear_min'
      timer = setTimeout ->
        reset(room)
      , clear_min * 60 * 1000

  # add (hot|cold) user
  robot.respond /air (hot|cold)$/i, (msg) ->
    type = msg.match[1]
    room = msg.envelope.room
    user = msg.envelope.user.name

    store[type].add(room, user)
    message(room, msg)

  # reset
  robot.respond /air done$/i, (msg) ->
    room = msg.envelope.room

    reset(room)
    message(room, msg)
