pub fn shorten(id: u64) -> String {
    let mut val = id;
    let mut key = String::new();
    while val != 0 {
        // println!("{} {}", crc32_hash % 62, UrlShorter::to62(crc32_hash % 62));
        key.push(to62((val % 62) as u32));
        val /= 62;
    }

    let key = key.chars().rev().collect::<String>();

    let response = format!("https://example.com/{}", key);
    return response;
}

fn to62(x: u32) -> char {
    match x {
        0..=35 => {
            let ch = std::char::from_digit(x, 36).unwrap();
            return ch;
        }
        36 => 'A',
        37 => 'B',
        38 => 'C',
        39 => 'D',
        40 => 'E',
        41 => 'F',
        42 => 'G',
        43 => 'H',
        44 => 'I',
        45 => 'J',
        46 => 'K',
        47 => 'L',
        48 => 'N',
        49 => 'M',
        50 => 'O',
        51 => 'P',
        52 => 'Q',
        53 => 'R',
        54 => 'S',
        55 => 'T',
        56 => 'U',
        57 => 'V',
        58 => 'W',
        59 => 'X',
        60 => 'Y',
        61 => 'Z',
        _ => return '?',
    }
}

mod tests {
    #[test]
    fn test() {
        let actual = crate::urlshorter::shorten(2009215674938);
        assert_eq!("https://example.com/zn9edcu", actual);
    }
}
