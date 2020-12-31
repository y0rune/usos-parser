#!/usr/bin/ruby
# coding: utf-8

require 'open-uri'
require 'nokogiri'
require 'spreadsheet'
require 'thread'
require 'thwait'

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

semestr = "Semestr zimowy 2019"

url = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/szukajPrzedmiotu&cp_showDescriptions=0&cp_showGroupsColumn=0&cp_cdydsDisplayLevel=2&f_tylkoWRejestracji=0&f_obcojezyczne=0&method=faculty_organized&kierujNaPlanyGrupy=0&jed_org_kod=0600000000&tab9b4e_offset=0&tab9b4e_limit=2000&tab9b4e_order=2a1a"
puts "URL: #{url}"
source = open(url, :read_timeout => 300).read

prz_kod = source.scan(/prz_kod=06-D\w*-*\w*-*\w*-*\w*-*/).uniq

file = File.open("output.csv", 'w')
file.puts "zaj_cyk_id,typ,kod,nazwa,nr_gr,Mc,dzien,godzina,sala,tytul,nazwisko,imie"
file.close

book = Spreadsheet::Workbook.new
sheet = book.create_worksheet(name: "#{semestr}")
sheet.row(0).push('zaj_cyk_id','typ','kod','nazwa','nr_gr','Mc','dzien','godzina','sala','stopien','nazwisko','imie')

j = 1
threads = []
prz_kod.each do |przkod|
    pokazPrzedmiotUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/pokazPrzedmiot&" + przkod
    puts "PrzedmiotUrl: #{pokazPrzedmiotUrl}"
    sleep 2
    pokazPrzedmiot = open(pokazPrzedmiotUrl, :open_timeout => 300).read
    semestrPrzedmiotu = pokazPrzedmiot.scan(semestr).uniq
    przedmiot = pokazPrzedmiot.scan(/<h1>.*/).uniq.to_s.sub("<h1>","").sub("</h1>","")

    if semestrPrzedmiotu != [] && (!przkod.match?('-E$'))
      zajCykId = pokazPrzedmiot.scan(/https.*zaj_cyk_id=[0-9]*/).to_s.scan(/[0-9]{2,}/)

      zajCykId.each do |zajcyk|
        zajCykUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/pokazGrupyZajec&zaj_cyk_id=" + zajcyk
        puts "PrzedmiotUrl: #{zajCykUrl}"

        zajCyk = open(zajCykUrl, :open_timeout => 300).read
        groups = zajCyk.scan(/strong grupa.*/).to_s.scan(/[0-9]{1,}/).uniq

        groups.each do |nrgrupy|
          threads << Thread.new {
          sleep 2
          typ, dzien, prowadzacyImie, prowadzacyNazwisko, prowadzacyStopien = ""
          dzienTygodnia = [/poniedziałek/,/wtorek/,/środa/,/czwartek/,/piątek/]
          typ = [/Praktyka/,/Ćwiczenia/,/Lektorat/,/Zajęcia laboratoryjne/,/Seminarium/,/Wykład/,/Konwersatorium/]

          grupaUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/przedmioty/pokazZajecia&zaj_cyk_id=" + zajcyk + "&gr_nr=" + nrgrupy

          puts "GrupaUrl: #{grupaUrl}"

          grupa = open(grupaUrl, :open_timeout => 300).read
          document = Nokogiri::HTML(grupa)
          table = document.css('div#layout-container div#layout-t2 div.layout-row main#layout-main-content div#layout-c22a div.wrtext table.grey').text.gsub!(/\s+/, ' ')
          semestrt = table.match(/Semestr.* [0-9]+\//).to_s.sub("/","")
          przedmiot = table.match(/Przedmiot.* 06/).to_s.sub("06","").sub("Przedmiot","").strip
          godzina = table.match(/[0-9]+:[0-9]+/)
          limitMiejsc = table.match(/Limit miejsc: [0-9]+/).to_s.match(/[0-9]+/)
          kod = table.match(/06-D\w*-*\w*-*\w*-*/).to_s.sub("06-","")
          prowadzacyKod = document.to_s.match('os_id=[0-9]+').to_s
          sala = table.match(/sala \p{L}+-*\w*-*\w*-*/).to_s.sub("sala","").strip

          if prowadzacyKod != ""
            prowadzacyUrl = "https://usosweb.amu.edu.pl/kontroler.php?_action=katalog2/osoby/pokazOsobe&" + prowadzacyKod
            puts "prowadzacyUrl: #{prowadzacyUrl}"
            prowadzacyWeb = Nokogiri::HTML(open(prowadzacyUrl, :open_timeout => 300).read)
            prowadzacyInfo = prowadzacyWeb.css('div#user-attrs-id').text.gsub!(/\s+/, ' ').strip
            prowadzacyImie = prowadzacyInfo.match(/Imiona.* Nazwisko/).to_s.sub("Imiona","").sub("Nazwisko","").to_s.match(/\p{L}+./).to_s.strip
            prowadzacyNazwisko = prowadzacyInfo.match(/Nazwisko.*Stopnie/).to_s.sub("Nazwisko","").sub("Stopnie","").strip
            prowadzacyStopien = prowadzacyInfo.match(/Stopnie.*/).to_s.sub("Stopnie i tytuły","").strip
            prowadzacyNazwisko = prowadzacyInfo.match(/Nazwisko .*/).to_s.sub("Nazwisko","").to_s.strip if prowadzacyNazwisko.nil? or prowadzacyNazwisko == ""
          end

          i = 0
          if (semestr == semestrt) && (kod != "") && (!kod.match?('-E$'))

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

            typ = "Laboratorium" if typ == "Zajęcia"
            zajcyk = "NULL" if zajcyk.nil?
            typ = "NULL" if typ.nil?
            kod = "NULL" if kod.nil?
            sala = "NULL" if sala.nil?
            przedmiot = "NULL" if przedmiot.nil?
            nrgrupy = "NULL" if nrgrupy.nil?
            limitMiejsc = "NULL" if limitMiejsc.nil?
            dzien = "NULL" if dzien.nil?
            godzina = "NULL" if godzina.nil?
            prowadzacyStopien = "NULL" if prowadzacyStopien.nil? or prowadzacyStopien == ""
            prowadzacyImie = "NULL" if prowadzacyImie.nil? or prowadzacyImie == ""
            prowadzacyNazwisko = "NULL" if prowadzacyNazwisko.nil? or prowadzacyNazwisko == ""

            file = File.open("output.csv", 'a')
            puts "Do pliku: #{zajcyk},#{typ},#{kod},#{przedmiot},#{nrgrupy},#{limitMiejsc},#{dzien},#{godzina},#{prowadzacyStopien},#{prowadzacyNazwisko},#{prowadzacyImie}"
            file.puts "#{zajcyk},#{typ},#{kod},#{przedmiot},#{nrgrupy},#{limitMiejsc},#{dzien},#{godzina},#{sala},#{prowadzacyStopien},#{prowadzacyNazwisko},#{prowadzacyImie}"

            sheet.row(j).push("#{zajcyk}","#{typ}","#{kod}","#{przedmiot}","#{nrgrupy}","#{limitMiejsc}","#{dzien}","#{godzina}","#{sala}","#{prowadzacyStopien}","#{prowadzacyNazwisko}","#{prowadzacyImie}")
            j = j + 1
          end
          }
        end
      end
    end
end
ThreadsWait.all_waits(*threads)
book.write "#{semestr}.xls"
file.close
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
elapsed = ending - starting

puts "Czas pracy: #{elapsed/60} min"
