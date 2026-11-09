# Dead SD card

I have a dd dump of a dead SD card at `/app/card.img`. The partition table and the filesystem structures are gone so nothing mounts. The card was formatted with 4096 byte clusters and it was nearly full when it died, so a lot of the photos ended up split across the card.

What I know about how the photos were stored:

- every photo starts at the beginning of a cluster
- a photo is in one piece or two pieces, never more. When there are two pieces, piece 1 comes before piece 2 on the card, but other data (including pieces of other photos) can sit between them
- each photo uses at most 14 clusters in total, counting both pieces but not any gap between them
- based on the camera's file-size records, a complete photo is between 28,000 and 51,000 bytes
- the last cluster of a photo is padded with zeros after the end of the jpeg data
- all the photos were taken with the same camera and settings
- the camera writes baseline, single-scan JPEGs without embedded preview images

Some photos got partly overwritten after the card was used and can't be fully recovered.

Write every photo that can be recovered to `/app/recovered/` as a separate `.jpg` file (create the directory). Each file has to be exactly the original photo, from its first byte to its last, with no padding or anything extra on either end. Don't put anything else in that directory, and don't write to `card.img`.
