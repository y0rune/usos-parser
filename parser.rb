#!/usr/bin/ruby
# coding: utf-8

require 'open-uri'
require 'nokogiri'
require 'csv'

semestr = "Semestr zimowy 2019"

url = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/szukajPrzedmiotu&cp_showDescriptions=0&cp_showGroupsColumn=0&cp_cdydsDisplayLevel=2&f_tylkoWRejestracji=0&f_obcojezyczne=0&method=faculty_organized&kierujNaPlanyGrupy=0&jed_org_kod=0600000000&tab9b4e_offset=0&tab9b4e_limit=2000&tab9b4e_order=2a1a"
puts "URL: #{url}"
source = open(url).read

prz_kod = source.scan(/prz_kod=06-D\w*-*\w*-*\w*-*\w*-*/).uniq

file = File.open("output.csv", 'w')
file.puts "zaj_cyk_id,typ,kod,nazwa,nr_gr,Mc,dzien,godzina,nazwisko,imie"
file.close

prz_kod.each do |przkod|
    pokazPrzedmiotUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/pokazPrzedmiot&" + przkod
    puts "PrzedmiotUrl: #{pokazPrzedmiotUrl}"
    pokazPrzedmiot = open(pokazPrzedmiotUrl).read
    semestrPrzedmiotu = pokazPrzedmiot.scan(semestr).uniq
    przedmiot = pokazPrzedmiot.scan(/<h1>.*/).uniq.to_s.sub("<h1>","").sub("</h1>","")

    if semestrPrzedmiotu != []
      zajCykId = pokazPrzedmiot.scan(/https.*zaj_cyk_id=[0-9]*/).to_s.scan(/[0-9]{2,}/)
      zajCykId.each do |zajcyk|
        zajCykUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/pokazGrupyZajec&zaj_cyk_id=" + zajcyk
        puts "PrzedmiotUrl: #{zajCykUrl}"
        zajCyk = open(zajCykUrl).read
        groups = zajCyk.scan(/strong grupa.*/).to_s.scan(/[0-9]{1,}/).uniq

        groups.each do |nrgrupy|
          sleep 2
          dzien = ""
          typ = ""
          dzienTygodnia = [/poniedziałek/,/wtorek/,/środa/,/czwartek/,/piątek/]
          typ = [/Ćwiczenia/,/Zajęcia laboratoryjne/,/Seminarium/,/Wykład/,/Konwersatorium/]
          grupaUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/pokazZajecia&zaj_cyk_id=" + zajcyk + "&gr_nr=" + nrgrupy
          puts "GrupaUrl: #{grupaUrl}"
          grupa = open(grupaUrl).read
          document = Nokogiri::HTML(grupa)
          table = document.css('div#layout-container div#layout-t2 div.layout-row main#layout-main-content div#layout-c22a div.wrtext table.grey').text.gsub!(/\s+/, ' ')
          semestrt = table.match(/Semestr.* [0-9]+\//).to_s.sub("/","")
          prowadzacy = table.match(/Prowadzący:.* Uwagi/).to_s.sub("Uwagi", "").to_s.sub("Prowadzący:", "").strip.split
          przedmiot = table.match(/Przedmiot.* 06/).to_s.sub("06","").sub("Przedmiot","").strip
          godzina = table.match(/[0-9]+:[0-9]+/)
          limitMiejsc = table.match(/Limit miejsc: [0-9]+/).to_s.match(/[0-9]+/)
          kod = table.match(/06-D\w*-*\w*-*\w*-*/).to_s.sub("06-","")

          i = 0
          if (semestr == semestrt) && (kod != "") #&& !(kod.match('-E$'))
            dzienTygodnia.each do |dz|
              i =+ 1
              if table.match(dz)
                #dzien = dz.to_s.match(/:\p{L}+/).to_s.sub(":","")
                dzien = i
              end
            end
            typ.each do |ty|
              if table.match(ty)
                typ = ty.to_s.match(/:\p{L}+/).to_s.sub(":","")
              end
            end
            if typ == "Zajęcia"
              typ = "Laboratorium"
            end
            file = File.open("output.csv", 'a')
            puts "#{zajcyk},#{typ},#{semestrt},#{przkod},#{przedmiot},#{nrgrupy},#{limitMiejsc},#{dzien},#{godzina},#{prowadzacy[1]},#{prowadzacy[0]}"
            file.puts "#{zajcyk},#{typ},#{kod},#{przedmiot},#{nrgrupy},#{limitMiejsc},#{dzien},#{godzina},#{prowadzacy[1]},#{prowadzacy[0]}"
            file.close
          end
        end
      end
    end
end
