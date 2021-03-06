require './utilities.rb'

# MAIN PROGRAM

begin

  # First get open the csv file and check the header:

  csv = CSV.open(get_input_file("sugarcanesites.csv"))

  # Check that the header row is what we expect
  EXPECTED_HEADER = %w(id usgsmuid city state country lat lon gdd
                       firstkillingfrost mat map masl soil zrt zh2o som notes
                       soilnotes created_at updated_at sitename greenhouse)
  header = csv.readline

  check_csv_header(header, EXPECTED_HEADER)


  # Now open a connection to the database:

  con = get_connection_interactively

  # Create a temporary table to keep track of the mapping between site
  # ids as listed in the csv file and the id numbers generated upon
  # inserting a site into the sites table
  create_temp_table(con, "temp_site_ids")

  INSERT_STRING = <<-INSERTION
    INSERT INTO sites(city, state, country, lat, lon, mat, map, masl, soil,
                      som, notes, soilnotes, created_at, updated_at, sitename,
                      greenhouse)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                COALESCE(?, NOW()), COALESCE(?, NOW()), ?, ?)
  INSERTION
  insert_statement = con.prepare(INSERT_STRING)

  # The query to get the generated id of site just inserted.  We assume
  # (lon, lat, sitename) form a natural key.  In particular, we assume
  # each is non-null.
  ID_QUERY_STRING = <<-SELECTION
    SELECT id FROM sites 
      WHERE lon = ? AND lat = ? AND sitename = ?
  SELECTION

  id_query = con.prepare(ID_QUERY_STRING)




  # Finally, iterate through the rows of the csv file and insert the
  # data into the sites table
  csv.each do |row|

    # assign row data to local varibles
    (id, usgsmuid, city, state, country, lat, lon,
     gdd, firstkillingfrost, mat, map, masl, soil, zrt, zh2o, som,
     notes, soilnotes, created_at, updated_at, sitename, greenhouse) = row


    # Display to the user what data is being inserted
    puts "city = #{city}"
    puts "state = #{state}"
    puts "country = #{country}"
    puts "lat = #{lat}"
    puts "lon = #{lon}"
    puts "mat = #{mat}"
    puts "map = #{map}"
    puts "masl = #{masl}"
    puts "soil = #{soil}"
    puts "som = #{som}"
    puts "notes = #{notes}"
    puts "soilnotes = #{soilnotes}"
    puts "created_at = #{created_at}"
    puts "updated_at = #{updated_at}"
    puts "sitename = #{sitename}"
    puts "greenhouse = #{greenhouse}"

    insert_statement.execute(city, state, country, lat, lon, mat,
                             map, masl, soil, som, notes,
                             soilnotes, created_at, updated_at,
                             sitename, greenhouse)

    # Now get the automatically-generated id number
    id_query.execute(lon, lat, sitename)
    row_count = id_query.size
    # Check that we get only the id for the row we just inserted--that
    # is, (lon, lat, sitename) should be unique
    if row_count == 0
      puts "Couldn't find a row with lon = #{lon}, lat = #{lat}, and sitename = #{sitename}"
      puts "Quitting"
      exit
    elsif row_count > 1
      puts "Found more than one row with lon = #{lon}, lat = #{lat}, and sitename = #{sitename}"
      puts "Quitting"
      exit
    end
    (id_number,) = id_query.fetch

    # Record the named-id --> id_number correspondence in the "temp_site_ids" table
    tempquery="INSERT INTO temp_site_ids(name, id) VALUES('#{id}', #{id_number})"
    con.query(tempquery)

  end # csv.each


rescue Mysql::Error => e
  puts e.errno
  puts e.error
  puts e.backtrace.join("\n")

ensure
  con.close if con
end
