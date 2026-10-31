/-
The UDP specification, from RFC 768 (User Datagram Protocol, J. Postel,
28 August 1980), written independently of the Rust crate and its
generated model (`Udp.Types`, `Udp.Funs`): the proofs relate the two.

    0      7 8     15 16    23 24    31
   +--------+--------+--------+--------+
   |     Source      |   Destination   |
   |      Port       |      Port       |
   +--------+--------+--------+--------+
   |                 |                 |
   |     Length      |    Checksum     |
   +--------+--------+--------+--------+
   |
   |          data octets ...
   +---------------- ...
-/

namespace Udp

/-- The UDP header: four 16-bit fields, each sent most significant octet
first (network byte order). The structure holds any four values, as they
are on the wire; which of them are valid is stated separately. -/
structure UdpHeader where
  /-- Source Port: optional. When meaningful, the port of the sending
  process, to which a reply should be addressed; 0 when not used. -/
  sourcePort : BitVec 16
  /-- Destination Port: the port the datagram is addressed to, meaningful
  within the context of a particular internet destination address. -/
  destinationPort : BitVec 16
  /-- Length: in octets, of this datagram, header and data together; at
  least 8 (the header alone). -/
  length : BitVec 16
  /-- Checksum: the 16-bit one's complement of the one's complement sum of
  a pseudo header of information from the IP header, the UDP header, and
  the data, padded with zero octets at the end (if necessary) to make a
  multiple of two octets. All zero means that the sender generated no
  checksum; a computed checksum of zero is sent as all ones. -/
  checksum : BitVec 16
  deriving DecidableEq, Repr

end Udp
