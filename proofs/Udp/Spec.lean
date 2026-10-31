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

The properties to prove about these definitions are stated in
`Udp/Invariants.lean`; `Udp/SpecTests.lean` evaluates the definitions on
datagrams worked out by hand from this RFC.
-/

namespace Udp

/-- An octet, as IP carries them. -/
abbrev Octet := BitVec 8

/-- The length of the header, in octets: four 16-bit fields. -/
def headerLength : Nat := 8

/-- The protocol number of UDP in the IP header: "Protocol = 17 (21 octal)". -/
def protocolNumber : Octet := 17

/-! ## The header -/

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

/-- The two octets of a 16-bit field, most significant first. -/
def toOctets16 (x : BitVec 16) : List Octet :=
  [x.extractLsb' 8 8, x.extractLsb' 0 8]

/-- The four octets of a 32-bit field, most significant first. -/
def toOctets32 (x : BitVec 32) : List Octet :=
  [x.extractLsb' 24 8, x.extractLsb' 16 8, x.extractLsb' 8 8, x.extractLsb' 0 8]

/-- The header on the wire: its fields in order, each most significant
octet first. -/
def UdpHeader.toOctets (h : UdpHeader) : List Octet :=
  toOctets16 h.sourcePort ++ toOctets16 h.destinationPort ++
    toOctets16 h.length ++ toOctets16 h.checksum

/-- The header in the first 8 octets; `none` if there are fewer. -/
def UdpHeader.ofOctets? : List Octet → Option UdpHeader
  | s₁ :: s₀ :: d₁ :: d₀ :: l₁ :: l₀ :: c₁ :: c₀ :: _ =>
    some { sourcePort := s₁ ++ s₀, destinationPort := d₁ ++ d₀,
           length := l₁ ++ l₀, checksum := c₁ ++ c₀ }
  | _ => none

/-! ## The datagram and its length -/

/-- A user datagram: the header and the data octets. -/
structure Datagram where
  header : UdpHeader
  data : List Octet
  deriving DecidableEq, Repr

/-- The datagram on the wire: the header, then the data. -/
def Datagram.toOctets (d : Datagram) : List Octet :=
  d.header.toOctets ++ d.data

/-- "Length is the length in octets of this user datagram including this
header and the data. (This means the minimum value of the length is
eight.)" -/
def Datagram.LengthValid (d : Datagram) : Prop :=
  d.header.length.toNat = headerLength + d.data.length

instance (d : Datagram) : Decidable d.LengthValid :=
  inferInstanceAs (Decidable (_ = _))

/-- The octets as a datagram: the header, then the data. `none` when there
are fewer than 8 octets, or when Length, "the length in octets of this user
datagram including this header and the data", is not the number of
octets. -/
def Datagram.ofOctets? (os : List Octet) : Option Datagram := do
  let h ← UdpHeader.ofOctets? os
  if h.length.toNat = os.length then
    some { header := h, data := os.drop headerLength }
  else
    none

/-! ## The checksum -/

/-- The information from the IP header that the checksum covers (IPv4).
With the zero octet, the protocol and the UDP length, it makes the pseudo
header, "conceptually prefixed to the UDP header". -/
structure PseudoHeader where
  sourceAddress : BitVec 32
  destinationAddress : BitVec 32
  deriving DecidableEq, Repr

/-- The pseudo header on the wire, for a datagram of `udpLength` octets:
source address, destination address, zero, protocol, UDP length. -/
def PseudoHeader.toOctets (p : PseudoHeader) (udpLength : BitVec 16) : List Octet :=
  toOctets32 p.sourceAddress ++ toOctets32 p.destinationAddress ++
    [0, protocolNumber] ++ toOctets16 udpLength

/-- One's complement addition of 16-bit words: binary addition with the
carry out of the top bit added back in ("end-around carry"). (RFC 768
says "one's complement sum"; this is what one's complement addition is.) -/
def onesAdd (a b : BitVec 16) : BitVec 16 :=
  let s := a.toNat + b.toNat
  BitVec.ofNat 16 (s % 2 ^ 16 + s / 2 ^ 16)

/-- Octets as 16-bit words, most significant octet first, the last padded
with a zero octet if there is an odd number. -/
def words : List Octet → List (BitVec 16)
  | [] => []
  | [a] => [a ++ (0 : Octet)]
  | a :: b :: rest => (a ++ b) :: words rest

/-- The one's complement sum of octets, as 16-bit words. -/
def onesSum (os : List Octet) : BitVec 16 :=
  (words os).foldl onesAdd 0

/-- What the checksum covers: the pseudo header, the header and the data.
The pseudo header's UDP length is the header's Length. -/
def checksumOctets (p : PseudoHeader) (d : Datagram) : List Octet :=
  p.toOctets d.header.length ++ d.toOctets

/-- The datagram with `c` in its Checksum field. -/
def Datagram.withChecksum (d : Datagram) (c : BitVec 16) : Datagram :=
  { d with header := { d.header with checksum := c } }

/-- The computed checksum: the one's complement of the one's complement
sum of what the checksum covers, its own field taken as zero. -/
def checksum (p : PseudoHeader) (d : Datagram) : BitVec 16 :=
  ~~~ onesSum (checksumOctets p (d.withChecksum 0))

/-- The checksum a sender puts in the datagram: "If the computed checksum
is zero, it is transmitted as all ones (the equivalent in one's complement
arithmetic)." -/
def transmittedChecksum (p : PseudoHeader) (d : Datagram) : BitVec 16 :=
  if checksum p d = 0 then BitVec.allOnes 16 else checksum p d

/-- A received datagram's checksum is right: "An all zero transmitted
checksum value means that the transmitter generated no checksum";
otherwise it is the one the sender should have put there. -/
def ChecksumValid (p : PseudoHeader) (d : Datagram) : Prop :=
  d.header.checksum = 0 ∨ d.header.checksum = transmittedChecksum p d

instance (p : PseudoHeader) (d : Datagram) : Decidable (ChecksumValid p d) :=
  inferInstanceAs (Decidable (_ ∨ _))

/-! ## Valid datagrams -/

/-- A datagram as RFC 768 defines it: its Length is its length, and its
checksum is either absent (all zero) or the computed one. -/
def Datagram.Valid (p : PseudoHeader) (d : Datagram) : Prop :=
  d.LengthValid ∧ ChecksumValid p d

instance (p : PseudoHeader) (d : Datagram) : Decidable (d.Valid p) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- The datagram a sender builds from ports and data: Length set, the
checksum computed. Meaningful when the data fit the 16-bit Length (at most
65527 octets). -/
def Datagram.build (p : PseudoHeader) (sourcePort destinationPort : BitVec 16)
    (data : List Octet) : Datagram :=
  let d : Datagram :=
    { header := { sourcePort, destinationPort,
                  length := BitVec.ofNat 16 (headerLength + data.length),
                  checksum := 0 },
      data }
  d.withChecksum (transmittedChecksum p d)

end Udp
