module.exports = {
  title: "efergy E2 config options"
  type: "object"
  properties:
    debug:
      description: "Log information for debugging, including received messages"
      type: "boolean"
      default: false
    binPath:
      description: "Path to the rtl_433 executable"
      type: "string"
      default: "/usr/local/bin/rtl_433"
    freq:
      description: "Carrier frequency (in Hz)"
      type: "number"
      default: 433550000
}