module.exports = {
  title: "efergy E2 config options"
  type: "object"
  properties:
    binPath:
      description: "Path to the rtl_433 executable"
      type: "string"
      default: "rtl_433"
    freq:
      description: "Carrier frequency (in Hz)"
      type: "number"
      default: 433550000
}