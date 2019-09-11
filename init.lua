
-- Thanks to a large number of people who's code I borrowed or reviewed
-- Paramat
-- Rubenwardy
-- Demon_boy
-- Duane
-- Burli
-- and a number of others who left code snippets and fix's on the forum boards.


-----------------------------------------------------------------
--               Set Map to Singlenode mode                    --
-----------------------------------------------------------------

minetest.set_mapgen_params({mgname = "singlenode"})


--------------------------------------------------------------------------
--                          Nodes to be used		  	                --
-------------------------------------------------------------------------- 
 
   local c_ignore = minetest.get_content_id("ignore")
   local c_air = minetest.get_content_id("air")

   
   local c_grass = minetest.get_content_id("default:dirt_with_grass")
   local c_sand = minetest.get_content_id("default:sand")
   local c_gravel = minetest.get_content_id("default:gravel")
   local c_stone = minetest.get_content_id("default:stone")
   local c_water = minetest.get_content_id("default:water_source")
   local c_ice = minetest.get_content_id("default:ice")  


-----------------------------------------------------------------
--     Bunch of variables used later on when generating the    -- 
--                     Ocean edge overlay                      --
-----------------------------------------------------------------

local map_gen_size = minetest.settings:get("mapgen_limit")                       -- Get the size of the map being generated from minetest.conf
local percent_land = 0.45                                                        -- approx % land
local xy_land_bndry = (map_gen_size*0.45)- (map_gen_size*0.04)                   -- the approximate node to start decaying downwards from on primary x and y axis 
local xy_land_bndry_off = math.floor(xy_land_bndry*0.75000)                      -- the approximate node to start decaying downwards when on diagonals 
local isl_hi = 0.8                                                               -- land height
local correction = math.floor(map_gen_size/1900)                                 -- calculation error increases as size increases.


	
 
--------------------------------------------------------------------------
--           Main Section to generate noise map to represent            -- 
--                      ocean around an island                          --
--        This is based on a standard S Decay Formula                   --
-- This was done mathmatically rather than using an image so as to keep --
--                      minetest security intact                        --
--     note: x and y = standard cartistion coordinates for 2 Axis       --
--     note: X, Y, Z = Standard minetest 3 Axis system                  --
--     note: x=X, y=Z, Decay algorithm provides value for Y             --
--     note: 2d noise usage only at this time                           --
--       Only need to store values down primary axis and off axis       --      
--------------------------------------------------------------------------
  
local nobj_volcano_ocean_2d_axis = {}
local nobj_volcano_ocean_2d_offaxis = {}
local scurve_ratio = 80/map_gen_size                 -- Dont adjust
local scurve_ratio_off = 105/map_gen_size            -- Dont adjust
local icp = 0 
 
while icp <= tonumber(map_gen_size) do
	
	nobj_volcano_ocean_2d_axis[icp]=((50+map_gen_size/80)/(1 + math.exp((0.3*scurve_ratio)*(icp)^0.95 + -3.16)))-(47 + map_gen_size/80)                   -- on axis X and Z values
	nobj_volcano_ocean_2d_offaxis[icp]=((50+map_gen_size/80)/(1 + math.exp((0.3*scurve_ratio_off)*(icp)^0.95 + -3.16)))-(47 + map_gen_size/80)            -- off AXIS XZ or ZX
	nobj_volcano_ocean_2d_offaxis[icp+0.5]=((50+map_gen_size/80)/(1 + math.exp((0.3*scurve_ratio_off)*(icp+0.5)^0.95 + -3.16)))-(47 + map_gen_size/80)    -- has half refernces
	
icp = icp+1
end 
  
-------------------------------------------------------------------------
--    Minetest register on generated, runs everytime a map block is    -- 
--     loaded. Note to self - keep unrequired stuff out of here        --
--       as it will slow map chunk generation down even more           -- 
-------------------------------------------------------------------------
					
minetest.register_on_generated(function(minp, maxp, seed)
local t0 = os.clock()    
	
	local write = false
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z	
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	
	local minpos2d = {x = x0 - 1, y = z0 - 1}
	local minpos3d = {x = x0 - 1, y = y0 - 1, z = z0 - 1}
	
	
   local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
   local data = vm:get_data()
   local a = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
  
   
   local csize_2d = vector.add(vector.subtract(maxp, minp), 1)                -- adds the vector for x,y,z to csize while doing this it subtracts max.x(yz) - min.x(yz)
   local csize_3d = vector.add(vector.subtract(maxp, minp), 1)                -- Unsure what the "1" does, tech manual is limitied on explanation, adopted from Burli's code
  
	
------------------------------------------------------------------------
----I had to do the same process on nobj_volcano_ocean_2d so I----------
-----create a table with needed values for later generation of the------ 
-----chunk. During this process I add some additional nested tables-----
--------------to flag the location of the crater/lava-------------------
------------------------------------------------------------------------
	
	nvals_ocean_2d = {}

                   
	i=1                                                                       -- Setup some counters for the below
	xi=0
	yi=0
	xs=tonumber(minp.x)                                                       -- intresting note 0,0 is not in the center of a chunk,
	ys=tonumber(minp.z)                                                       -- deduct -8 from X and Z to get true center,

	while i<=6401 do
		if xi < 80 then
			local xxs = xs+xi
			local yys = ys+yi
			local xxss = math.abs(xxs)
			local yyss = math.abs(yys)	
		
			-------------------Standard Decay for Ocean y--------------------
			if yyss >= xxss                                  	    
			 and(xxss/yyss) <= 0.5  then

							if yyss < xy_land_bndry then
								table.insert(nvals_ocean_2d,isl_hi)
							else
							table.insert(nvals_ocean_2d,nobj_volcano_ocean_2d_axis[yyss-xy_land_bndry]+correction)
							end
			
			-------------------Standard Decay for Ocean yx-------------------				
			elseif yyss >= xxss                                    
		     and (xxss/yyss) > 0.5 then  

							if ((yyss+xxss)*0.5) < xy_land_bndry_off then
								table.insert(nvals_ocean_2d,isl_hi)
							else				   
								table.insert(nvals_ocean_2d,nobj_volcano_ocean_2d_offaxis[((yyss+xxss)*0.5)-xy_land_bndry_off]+correction)
							end

			-------------------Standard Decay for Ocean x--------------------		   
			elseif xxss >= yyss                                     
			 and(yyss/xxss) <= 0.5 then 

							if xxss < xy_land_bndry then
								table.insert(nvals_ocean_2d,isl_hi)
							else				   
                                  table.insert(nvals_ocean_2d,nobj_volcano_ocean_2d_axis[xxss-xy_land_bndry]+correction)
							end
						
	       -------------------Standard Decay for Ocean xy-------------------	   
				elseif xxss  >= yyss                          
			     and(yyss/xxss)  > 0.5  then  
							if ((yyss+xxss)*0.5) < xy_land_bndry_off then
								table.insert(nvals_ocean_2d,isl_hi)
							else					   
								table.insert(nvals_ocean_2d,nobj_volcano_ocean_2d_offaxis[((yyss+xxss)*0.5)-xy_land_bndry_off]+correction)
							end

		   ----------------------Set 0,0 as its not covered above----------------------
				elseif xxss == 0 
				  and yyss == 0 then     
						table.insert(nvals_ocean_2d,isl_hi) 
									
			------ Cleans up some missed cases on the map edge - fix better later	-----
				else
					table.insert(nvals_ocean_2d,nobj_volcano_ocean_2d_axis[tonumber(map_gen_size)-xy_land_bndry]+correction) 
						
				end
			i=i+1                                                                           		-- Increment counters
			xi=xi+1
		else
			yi=yi+1                                                                     -- We are at the end of a row so increment y and reset x
			xs=minp.x
			xi=0
								
		end
	end	
	

------------------------------------------------------------------------ 
-- End of nvals_ocean_2d creation, at this point nvals_ocean_2d holds --
-- values for 1 mapchunk assuming mapchunk is 80x80                   --
------------------------------------------------------------------------  
   local index2d = 0
   
   for z = minp.z, maxp.z do
	   for y = minp.y, maxp.y do
		   for x = minp.x, maxp.x do

			  
			 local index2d = (z - minp.z) * csize_2d.x + (x - minp.x) + 1
			 local ivm = a:index(x, y, z)

			 local density_noise = nvals_ocean_2d[index2d]/10
			 local density_gradient = (1 - y) / 15
		  

				  if density_noise + density_gradient > 0 and  density_noise + density_gradient <= 1 and y > 1 and y < 50 then
					 data[ivm] = c_grass

				  elseif density_noise + density_gradient > 0 and  density_noise + density_gradient <= 1 and y >= 50 then
					 data[ivm] = c_stone	 
					 
				  elseif density_noise + density_gradient > 0 and  density_noise + density_gradient <= 1 and y <= 1 then
					 data[ivm] = c_sand	
					 
				  elseif density_noise + density_gradient > 1 then
					 data[ivm] = c_stone

				  elseif y < 1 then
					data[ivm] = c_water	

				  end 

		   end
	   end
   end

      vm:set_data(data)
      vm:set_lighting({day = 0, night = 0})
      vm:calc_lighting()
      vm:write_to_map()
      vm:update_liquids()

	local chugent = math.ceil((os.clock() - t0) * 1000)
	minetest.chat_send_player("singleplayer","Ocean chunk gen time: " .. chugent .. " ms")   
end)
