/-
What RFC 768 says, as properties of the definitions in `Udp.Spec`, each
with the text it comes from. Statements only: the proofs are to be written.
-/
import Udp.Spec

namespace Udp

/-! ## Format

      0      7 8     15 16    23 24    31
     +--------+--------+--------+--------+
     |     Source      |   Destination   |
     |      Port       |      Port       |
     +--------+--------+--------+--------+
     |                 |                 |
     |     Length      |    Checksum     |
     +--------+--------+--------+--------+
-/

/--Helper theorem for bit extraction  -/
theorem extractLsb'_append (x : BitVec 16) :
    x.extractLsb' 8 8 ++ x.extractLsb' 0 8 = x := by
  ext i hi
  rw[BitVec.getElem_append]
  split
  next hlt =>
    rw[BitVec.getElem_extractLsb', Nat.zero_add, BitVec.getLsbD_eq_getElem]
  next hge =>
    have add_8: 8 + (i - 8) = i := by
      omega
    rw[BitVec.getElem_extractLsb', add_8 ,BitVec.getLsbD_eq_getElem]

theorem octet_concat( a b : Octet): a ++ b = BitVec.append a b := by
  grind

/-- The header is four 16-bit fields: 8 octets. -/
theorem UdpHeader.toOctets_length (h : UdpHeader) :
    h.toOctets.length = headerLength := by
  rfl

/-- Each field has its own place in the header: the header is read back
from its octets, whatever follows them. -/
theorem UdpHeader.ofOctets?_toOctets (h : UdpHeader) (rest : List Octet) :
    UdpHeader.ofOctets? (h.toOctets ++ rest) = some h := by
  unfold UdpHeader.ofOctets? toOctets toOctets16
  simp only [List.cons_append, List.nil_append, extractLsb'_append]

/-- The header is the first 8 octets, so there is one whenever there are
8 octets. -/
theorem UdpHeader.ofOctets?_isSome {os : List Octet} :
    (UdpHeader.ofOctets? os).isSome ↔ headerLength ≤ os.length := by
  unfold UdpHeader.ofOctets?
  split
  next hlt =>
    simp
    unfold headerLength
    grind
  next hlr =>
  simp at hlr
  unfold headerLength
  match os, hlr with
    | s₁ :: s₀ :: d₁ :: d₀ :: l₁ :: l₀ :: c₁ :: c₀ :: tail, hlr => exact absurd rfl (hlr s₁ s₀ d₁ d₀ l₁ l₀ c₁ c₀ tail)
    | [], _
    | [_], _
    | [_, _], _
    | [_, _, _], _
    | [_, _, _, _], _
    | [_, _, _, _, _], _
    | [_, _, _, _, _, _], _
    | [_, _, _, _, _, _, _], _ => simp
/-! ## Length

"Length is the length in octets of this user datagram including this
header and the data. (This means the minimum value of the length is
eight.)"
-/

/-- "The minimum value of the length is eight." -/
theorem Datagram.LengthValid.headerLength_le {d : Datagram} (h : d.LengthValid) :
    headerLength ≤ d.header.length.toNat := by
  unfold Datagram.LengthValid at h
  rw[h]
  omega

/-- Length is a 16-bit field, so the data are at most 2¹⁶ − 1 − 8 octets. -/
theorem Datagram.LengthValid.data_length_le {d : Datagram} (h : d.LengthValid) :
    d.data.length ≤ 2 ^ 16 - 1 - headerLength := by
  unfold Datagram.LengthValid headerLength at h
  unfold headerLength
  have hlt := BitVec.isLt d.header.length
  omega

/-- "The length in octets of this user datagram including this header and
the data." -/
theorem Datagram.LengthValid.toOctets_length {d : Datagram} (h : d.LengthValid) :
    d.toOctets.length = d.header.length.toNat := by
  unfold Datagram.LengthValid at h
  rw[h]
  unfold Datagram.toOctets UdpHeader.toOctets toOctets16 headerLength
  simp
  omega

/-- A datagram whose Length is its length is read back from its octets. -/
theorem Datagram.ofOctets?_toOctets {d : Datagram} (h : d.LengthValid) :
    Datagram.ofOctets? d.toOctets = some d := by
  unfold Datagram.ofOctets? Datagram.toOctets
  rw[UdpHeader.ofOctets?_toOctets]
  simp
  constructor
  . exact h
  . rw[List.drop_left' (UdpHeader.toOctets_length d.header) ]


/-- Octets read as a datagram are that datagram's octets, and its Length is
its length. -/
theorem Datagram.ofOctets?_eq_some {os : List Octet} {d : Datagram}
    (h : Datagram.ofOctets? os = some d) :
    d.LengthValid ∧ d.toOctets = os := by
    unfold Datagram.ofOctets? at h
    cases hh : UdpHeader.ofOctets? os with
      | none  =>
        simp [hh] at h
      | some a  =>
        simp[hh] at h
        obtain ⟨hlen, rfl ⟩ := h
        sorry



/-! ## Checksum

"Checksum is the 16-bit one's complement of the one's complement sum of a
pseudo header of information from the IP header, the UDP header, and the
data, padded with zero octets at the end (if necessary) to make a multiple
of two octets. […] If the computed checksum is zero, it is transmitted as
all ones (the equivalent in one's complement arithmetic). An all zero
transmitted checksum value means that the transmitter generated no
checksum."
-/

/-- "If the computed checksum is zero, it is transmitted as all ones": a
sender that computed a checksum never sends all zero, which would mean it
generated none. -/
theorem transmittedChecksum_ne_zero (p : PseudoHeader) (d : Datagram) :
    transmittedChecksum p d ≠ 0 := by
    unfold transmittedChecksum
    grind

/-- "The equivalent in one's complement arithmetic": all ones and all zero
are the same number, so what is transmitted is the computed checksum, as a
one's complement number. -/
theorem transmittedChecksum_eq (p : PseudoHeader) (d : Datagram) :
    transmittedChecksum p d = checksum p d ∨
      (checksum p d = 0 ∧ transmittedChecksum p d = BitVec.allOnes 16) := by
  unfold transmittedChecksum
  grind

/-- The checksum is computed with its own field taken as zero, so writing
it into the datagram does not change it. -/
theorem checksum_withChecksum (p : PseudoHeader) (d : Datagram) (c : BitVec 16) :
    checksum p (d.withChecksum c) = checksum p d := by
  unfold checksum Datagram.withChecksum
  grind

/-- "An all zero transmitted checksum value means that the transmitter
generated no checksum": such a datagram's checksum is never wrong. -/
theorem checksumValid_zero (p : PseudoHeader) (d : Datagram) :
    ChecksumValid p (d.withChecksum 0) := by
  unfold ChecksumValid
  left
  rfl

/-- A checksum other than all zero was generated by the sender, and is
right only if it is the one computed. -/
theorem checksumValid_iff {p : PseudoHeader} {d : Datagram} (h : d.header.checksum ≠ 0) :
    ChecksumValid p d ↔ d.header.checksum = transmittedChecksum p d := by
    unfold ChecksumValid transmittedChecksum
    simp
    split
    next hlt =>
      grind
    next hlr =>
      grind
/-! ## Sending

A sender sets Length to the length of the datagram, and the checksum to the
one computed.
-/

/-- The datagram built has the ports and data it was built from. -/
theorem Datagram.build_fields (p : PseudoHeader) (sourcePort destinationPort : BitVec 16)
    (data : List Octet) :
    let d := Datagram.build p sourcePort destinationPort data
    d.header.sourcePort = sourcePort ∧ d.header.destinationPort = destinationPort ∧
      d.data = data := by
    unfold UdpHeader.destinationPort
    sorry

/-- When the data fit the 16-bit Length, the datagram built is valid. -/
theorem Datagram.build_valid (p : PseudoHeader) (sourcePort destinationPort : BitVec 16)
    {data : List Octet} (h : data.length ≤ 2 ^ 16 - 1 - headerLength) :
    (Datagram.build p sourcePort destinationPort data).Valid p := by
    unfold Datagram.Valid Datagram.LengthValid headerLength ChecksumValid
    unfold headerLength at h
    simp at h
    constructor
    . unfold build Datagram.withChecksum headerLength
      simp
      omega
    . right
      unfold build transmittedChecksum
      rw[checksum_withChecksum]
      unfold headerLength
      dsimp
      rfl

/-- When the data fit, the datagram built is read back from its octets. -/
theorem Datagram.ofOctets?_build (p : PseudoHeader) (sourcePort destinationPort : BitVec 16)
    {data : List Octet} (h : data.length ≤ 2 ^ 16 - 1 - headerLength) :
    let d := Datagram.build p sourcePort destinationPort data
    Datagram.ofOctets? d.toOctets = some d := by
    intro d
    apply Datagram.ofOctets?_toOctets
    exact (Datagram.build_valid p sourcePort destinationPort h).left
end Udp
