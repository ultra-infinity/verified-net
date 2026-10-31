/-
The definitions of `Udp.Spec`, evaluated on datagrams worked out by hand
from RFC 768: a check that they say what the RFC means, not a proof.

All are from 10.0.0.1 to 10.0.0.2, Source Port 1, Destination Port 2.
Their pseudo header, as 16-bit words, is

    0a00 0001  0a00 0002  0011 llll

(addresses, zero and protocol 17, UDP length llll), and their header, with
the checksum taken as zero, is

    0001 0002 llll 0000
-/
import Udp.Spec

namespace Udp.SpecTests

open Udp

def p : PseudoHeader := { sourceAddress := 0x0A000001, destinationAddress := 0x0A000002 }

/-
One data octet, 61. Length 9 = 0009. The data, padded, is the word 6100.
  0a00 + 0001 + 0a00 + 0002 + 0011 + 0009        = 141d  (pseudo header)
  141d + 0001 + 0002 + 0009 + 0000               = 1429  (header)
  1429 + 6100                                    = 7529  (data)
Checksum: ~7529 = 8ad6.
-/
def odd : List Octet := [0x00, 0x01, 0x00, 0x02, 0x00, 0x09, 0x8a, 0xd6, 0x61]

/-
Data ff ff ff ff. Length 12 = 000c. The sum carries out of the top bit, and
the carry comes back in (end-around carry):
  0a00 + 0001 + 0a00 + 0002 + 0011 + 000c        = 1420
  1420 + 0001 + 0002 + 000c + 0000               = 142f
  142f + ffff = 1 142e → 142e + 1                = 142f
  142f + ffff = 1 142e → 142e + 1                = 142f
Checksum: ~142f = ebd0.
-/
def carries : List Octet :=
  [0x00, 0x01, 0x00, 0x02, 0x00, 0x0c, 0xeb, 0xd0, 0xff, 0xff, 0xff, 0xff]

/-
Data eb d4. Length 10 = 000a:
  0a00 + 0001 + 0a00 + 0002 + 0011 + 000a        = 141e
  141e + 0001 + 0002 + 000a + 0000               = 142b
  142b + ebd4                                    = ffff
The computed checksum is ~ffff = 0000, so "it is transmitted as all ones":
ffff.
-/
def computedZero : List Octet := [0x00, 0x01, 0x00, 0x02, 0x00, 0x0a, 0xff, 0xff, 0xeb, 0xd4]

-- Built, the datagrams are the octets worked out above.
#guard (Datagram.build p 1 2 [0x61]).toOctets == odd
#guard (Datagram.build p 1 2 [0xff, 0xff, 0xff, 0xff]).toOctets == carries
#guard (Datagram.build p 1 2 [0xeb, 0xd4]).toOctets == computedZero
#guard checksum p (Datagram.build p 1 2 [0xeb, 0xd4]) == 0

-- Read back, they are the datagrams built, and valid.
#guard Datagram.ofOctets? odd == some (Datagram.build p 1 2 [0x61])
#guard Datagram.ofOctets? carries == some (Datagram.build p 1 2 [0xff, 0xff, 0xff, 0xff])
#guard Datagram.ofOctets? computedZero == some (Datagram.build p 1 2 [0xeb, 0xd4])
#guard [odd, carries, computedZero].all fun os =>
  (Datagram.ofOctets? os).any fun d => decide (d.Valid p)

-- Fewer than 8 octets; Length less than 8; Length not the number of
-- octets: not a datagram.
#guard Datagram.ofOctets? (odd.take 7) == none
#guard Datagram.ofOctets? [0x00, 0x01, 0x00, 0x02, 0x00, 0x07, 0x00, 0x00] == none
#guard Datagram.ofOctets? (odd ++ [0]) == none
#guard Datagram.ofOctets? (odd.dropLast) == none

-- "An all zero transmitted checksum value means that the transmitter
-- generated no checksum": valid whatever the data.
#guard decide (ChecksumValid p ((Datagram.build p 1 2 [0x61]).withChecksum 0))

-- Data changed, checksum not: not valid.
#guard !decide (ChecksumValid p { Datagram.build p 1 2 [0x61] with data := [0x62] })

-- The checksum covers the pseudo header: another destination address, not
-- valid.
#guard !decide (ChecksumValid { p with destinationAddress := 0x0A000003 }
  (Datagram.build p 1 2 [0x61]))

end Udp.SpecTests
