// ==========================================
// ECU HEAVY DUTY - V49 (SIDE BLADES & FLOOR FIX)
// ==========================================

// --- [0] VISUALIZZAZIONE ---
show_ghost = true; 

// --- [1] DATI REALI PCB ---
pcb_dim_x = 72.0; 
pcb_dim_y = 84.9;
pcb_thick = 1.6;

// --- [2] PARAMETRI MOUNTING ---
mounting_dist   = 115.0; 
mounting_hole_d = 7.0;   
tab_width       = 20.0;  

// --- [3] CALIBRAZIONE CONNETTORE ---
blade_extra_height = 4.0; 
wall_interface_thick = 1.5; 
conn_x_center = 36.0;   
conn_y_shift = 3.0;  
conn_z_shift = 0.0;     
conn_cut_width = 30.0;  
conn_pcb_offset = 5.0; 

// --- [4] SETTAGGI VARI ---
h_comp_bot = 0.5;      
pcb_recess = 0.0;     
h_comp_top = 12.0;      

// Spessore 7mm (BUNKER)
wall_main = 7.0;      
tolerance = 0.8;      

conn_h_inner = 14.0;        
conn_body_clearance = 3.5;
fins_height = 5.0; fins_base_thick = 2.5; fins_top_thick = 1.5; fins_gap = 3.5;    
oring_w = 2.6; oring_d = 1.8; 
lip_h = 1.4; 
lip_w = 1.5; 
corner_r = 4.0;
boss_diam = 9.0; boss_base = 13.0;     

// --- POSIZIONE FORI ---
h1_x = 4.02; h1_y = 3.268;
h2_x = 68.3; h2_y = 3.268;
h3_x = 4.30; h3_y = 73.343;
h4_x = 67.57; h4_y = 80.22;
pcb_holes = [[h1_x, h1_y], [h2_x, h2_y], [h3_x, h3_y], [h4_x, h4_y]];

// ==========================================
// RENDER
// ==========================================
$fn = 60;

z_split = wall_main + h_comp_bot + pcb_thick + pcb_recess;
oz = wall_main + h_comp_bot + pcb_thick + pcb_recess + h_comp_top + wall_main;

if(show_ghost) {
    %translate([wall_main + tolerance, wall_main + tolerance, wall_main + h_comp_bot]) 
        Ghost_System();
}

translate([0,0,0]) Bottom_Shell();
translate([pcb_dim_x + 80, 0, 0]) Top_Shell();

// ==========================================
// MODULI SCATOLA
// ==========================================

module Bottom_Shell() {
    difference() {
        union() {
            difference() {
                intersection() {
                    Shell_Body();
                    translate([-50,-50, -10]) cube([300, 300, z_split + 10]);
                }
                Internal_Void_Robust(); 
                
                difference() {
                    Oring_System(mode="cut_groove");
                    Connector_Zone_Mask();
                }
            }
            // Aggiungo il "Biscotto" solido per il connettore (più largo del buco)
            Connector_Blade_Solid_Block("bottom");
            
            Screw_Bosses_Simple(type="bottom");
            Mounting_Tabs_Fixed(); 
        }
        
        // ORA SCALPELLO VIA IL BUCO E L'ECCESSO
        Connector_Cut_Hole_Tunnel(); 
        Connector_Cut_Thinning_Limited("bottom"); 
        Screw_Holes(type="bottom");
    }
}

module Top_Shell() {
    difference() {
        union() {
            difference() {
                intersection() {
                    Shell_Body();
                    translate([-50,-50, z_split]) cube([300, 300, 100]);
                }
                Internal_Void_Robust(); 
            }
            intersection() {
                Shell_Body();
                Screw_Bosses_Simple(type="top");
            }
            
            // Aggiungo il "Biscotto" superiore intersecato
            intersection() {
                Shell_Body(); 
                Connector_Blade_Solid_Block("top");
            }

            difference() {
                Oring_System(mode="add_lip");
                Connector_Zone_Mask();
            }
            Cooling_Fins_Safe();
        }
        
        // SCALPELLO
        Connector_Cut_Hole_Tunnel(); 
        Connector_Cut_Thinning_Limited("top");
        Screw_Holes(type="top");
    }
}

// ==========================================
// 1. IL BLOCCO SOLIDO (LA MATERIA PRIMA DELLA LAMA)
// ==========================================
module Connector_Blade_Solid_Block(type) {
    abs_conn_center = wall_main + tolerance + conn_x_center;
    blade_center_y = (wall_main / 2) + conn_y_shift;
    
    // FIX FONDAMENTALE: Facciamo il blocco PIÙ LARGO del buco.
    // Buco = 30mm. Blocco = 30 + 6 = 36mm.
    // Quando bucheremo 30mm al centro, resteranno 3mm per lato -> PARETI LATERALI!
    block_width = conn_cut_width + 6.0; 
    
    if (type == "bottom") {
        base_z = z_split; 
        translate([abs_conn_center - (block_width/2), blade_center_y - (wall_interface_thick/2), 0])
            cube([block_width, wall_interface_thick, base_z + blade_extra_height]);
            
        // Rinforzo pavimento sotto la lama (per non avere buchi sotto)
        translate([abs_conn_center - (block_width/2), blade_center_y - 4, 0])
            cube([block_width, 8, wall_main]);
    }
    
    if (type == "top") {
        // Parte dallo split e sale
        translate([abs_conn_center - (block_width/2), blade_center_y - (wall_interface_thick/2), z_split - 0.1])
            cube([block_width, wall_interface_thick, 50]); 
    }
}

// ==========================================
// 2. IL BUCO (TUNNEL)
// ==========================================
module Connector_Cut_Hole_Tunnel() {
    abs_conn_center = wall_main + tolerance + conn_x_center ;
    base_z_center = wall_main + h_comp_bot + pcb_thick + (conn_h_inner/2) + conn_z_shift;
    
    // Tunnel limitato in profondità per non bucare il retro della scatola
    // Taglia esattamente conn_cut_width (30mm).
    // Siccome il blocco solido è 36mm, restano 3mm per lato.
    translate([abs_conn_center, 0, base_z_center]) 
        cube([conn_cut_width, 60, conn_h_inner+1], center=true);
}

// ==========================================
// 3. ASSOTTIGLIAMENTO LIMITATO (SICUREZZA)
// ==========================================
module Connector_Cut_Thinning_Limited(type) {
    abs_conn_center = wall_main + tolerance + conn_x_center;
    blade_center_y = (wall_main / 2) + conn_y_shift;
    blade_start_y = blade_center_y - (wall_interface_thick/2);
    blade_end_y   = blade_center_y + (wall_interface_thick/2);
    
    // Definiamo i limiti sicuri per lo scavo
    // NON SCENDERE MAI SOTTO IL PAVIMENTO (7mm)
    safe_bottom_z = wall_main; 
    
    // NON SALIRE MAI SOPRA L'INIZIO DELLA CURVA DEL TETTO
    // Il tetto finisce a OZ. La curva è R=4. Quindi sicuro fino a OZ - 4.
    safe_top_z = oz - 4.0;
    
    // Altezza del connettore + extra
    base_z_pcb = wall_main + h_comp_bot + pcb_thick + conn_z_shift;
    target_cut_height = conn_h_inner + blade_extra_height; 
    
    // Calcoliamo dove deve stare il taglio in Z
    // Lo "clampiamo" (blocchiamo) tra safe_bottom e safe_top
    cut_z_start = max(safe_bottom_z, base_z_pcb - 5); // Un po' di margine sotto il pcb
    cut_z_end   = min(safe_top_z, base_z_pcb + target_cut_height);
    
    real_cut_h = cut_z_end - cut_z_start;
    
    // Se per qualche motivo siamo fuori range, non tagliare nulla
    if (real_cut_h > 0) {
        // Taglio Frontale (Davanti alla lama)
        translate([abs_conn_center - (conn_cut_width/2 + 2), -30 + blade_start_y, cut_z_start]) 
            cube([conn_cut_width + 4, 30, real_cut_h]);

        // Taglio Posteriore (Dietro la lama)
        translate([abs_conn_center - (conn_cut_width/2 + 2), blade_end_y, cut_z_start])   
            cube([conn_cut_width + 4, 30, real_cut_h]);
    }
}

// ==========================================
// ALTRI MODULI
// ==========================================
module Internal_Void_Robust() {
    ix = pcb_dim_x + tolerance*2;
    iy = pcb_dim_y + tolerance*2;
    z_start = wall_main;
    z_height = oz - (wall_main * 2); 
    r_int = 2.0;
    translate([wall_main, wall_main, z_start]) 
    hull() {
        translate([r_int, r_int, 0]) cylinder(r=r_int, h=z_height);
        translate([ix - r_int, r_int, 0]) cylinder(r=r_int, h=z_height);
        translate([r_int, iy - r_int, 0]) cylinder(r=r_int, h=z_height);
        translate([ix - r_int, iy - r_int, 0]) cylinder(r=r_int, h=z_height);
    }
}

module Mounting_Tabs_Fixed() {
    ox = pcb_dim_x + tolerance*2 + wall_main*2;
    oy = pcb_dim_y + tolerance*2 + wall_main*2;
    center_x = ox / 2;
    center_y = oy / 2;
    offset_dist = mounting_dist / 2;
    
    // Posteriore
    pos_back_y = center_y + offset_dist;
    translate([center_x, pos_back_y, 0]) difference() {
        hull() {
            cylinder(d=tab_width, h=wall_main);
            translate([-tab_width/2, -(pos_back_y - oy) - 1, 0]) cube([tab_width, 2, wall_main]);
        }
        translate([0,0,-1]) cylinder(d=mounting_hole_d, h=wall_main+2);
    }
    
    // Anteriore (U-Shape)
    pos_front_y = center_y - offset_dist;
    translate([center_x, pos_front_y, 0]) difference() {
        hull() {
            cylinder(d=tab_width, h=wall_main);
            translate([-tab_width/2, -pos_front_y - 1, 0]) cube([tab_width, 2, wall_main]);
        }
        hull() {
            translate([0,0,-1]) cylinder(d=mounting_hole_d, h=wall_main+2);
            translate([0, -20, -1]) cylinder(d=mounting_hole_d, h=wall_main+2);
        }
    }
}

module Connector_Zone_Mask() {
    abs_conn_center = wall_main + tolerance + conn_x_center;
    mask_w = conn_cut_width + 4; 
    translate([abs_conn_center, 0, 0]) cube([mask_w, wall_main*4, 200], center=true);
}

module Shell_Body() {
    ox = pcb_dim_x + tolerance*2 + wall_main*2;
    oy = pcb_dim_y + tolerance*2 + wall_main*2;
    r = 4.0;
    hull() {
        translate([r, r, r]) sphere(r=r); translate([ox-r, r, r]) sphere(r=r);
        translate([r, oy-r, r]) sphere(r=r); translate([ox-r, oy-r, r]) sphere(r=r);
        translate([r, r, oz-r]) sphere(r=r); translate([ox-r, r, oz-r]) sphere(r=r);
        translate([r, oy-r, oz-r]) sphere(r=r); translate([ox-r, oy-r, oz-r]) sphere(r=r);
    }
}

module Screw_Bosses_Simple(type) {
    offset_x = wall_main + tolerance;
    offset_y = wall_main + tolerance;
    for(coord = pcb_holes) {
        pos_x = coord[0] + offset_x; pos_y = coord[1] + offset_y;
        translate([pos_x, pos_y, 0]) {
            if(type=="bottom") {
                h_boss = h_comp_bot + 0.1; 
                translate([0,0, wall_main-0.1]) cylinder(d=boss_diam, h=h_boss);
                translate([0,0, wall_main-0.1]) cylinder(d1=boss_base, d2=boss_diam, h=h_boss);
            }
            if(type=="top") { translate([0,0, z_split]) cylinder(d=boss_diam, h=50); }
        }
    }
}

module Screw_Holes(type) {
    offset_x = wall_main + tolerance; offset_y = wall_main + tolerance;
    for(coord = pcb_holes) {
        pos_x = coord[0] + offset_x; pos_y = coord[1] + offset_y;
        translate([pos_x, pos_y, 0]) {
            if(type=="bottom") {
                translate([0,0,-5]) cylinder(d=3.2, h=50); 
                translate([0,0,-1]) cylinder(d=6.0, h=wall_main/2 + 2); 
            }
            if(type=="top") { translate([0,0, z_split]) cylinder(d=2.8, h=15); }
        }
    }
}

module Cooling_Fins_Safe() {
    ox_total = pcb_dim_x + tolerance*2 + wall_main*2; oy_total = pcb_dim_y + tolerance*2 + wall_main*2;
    padding_x = wall_main; padding_y = wall_main; 
    area_start_x = padding_x; area_end_x = ox_total - padding_x;
    area_start_y = padding_y; fin_length = oy_total - (padding_y * 2);
    z_start = oz - 0.5; step = fins_base_thick + fins_gap;
    translate([0,0,z_start])
    for (x = [area_start_x : step : area_end_x - fins_base_thick]) { 
        translate([x, area_start_y, 0]) hull() {
            cube([fins_base_thick, fin_length, 0.1]);
            translate([(fins_base_thick - fins_top_thick)/2, 0, fins_height]) cube([fins_top_thick, fin_length, 0.1]);
        }
    }
}

module Oring_System(mode) {
    ox = pcb_dim_x + tolerance*2 + wall_main*2; oy = pcb_dim_y + tolerance*2 + wall_main*2;
    ix = pcb_dim_x + tolerance*2; iy = pcb_dim_y + tolerance*2;
    path_w = ix + (2.5 * 2) + oring_w; path_d = iy + (2.5 * 2) + oring_w;
    translate([ox/2, oy/2, z_split]) { 
        if (mode == "cut_groove") { 
            translate([0,0, -oring_d]) 
                rounded_frame_center(path_w, path_d, oring_w, oring_d * 2, corner_r);
        }
        if (mode == "add_lip") { 
            translate([0,0, -lip_h]) 
                rounded_frame_center(path_w, path_d, lip_w, lip_h + 0.1, corner_r);
        }
    }
}

module Ghost_System() {
    color("green", 0.3) cube([pcb_dim_x, pcb_dim_y, pcb_thick]);
    color("red") for(coord = pcb_holes) translate([coord[0], coord[1], -10]) cylinder(r=1.5, h=30);
    conn_y_sim = -conn_pcb_offset; z_preview = pcb_thick + (conn_h_inner/2) + conn_z_shift;
    color("orange", 0.6) {
        translate([conn_x_center, conn_y_sim, z_preview]) {
            difference() {
                cube([conn_cut_width-2, 20, conn_h_inner], center=true); 
                translate([0, 10 + conn_y_sim + conn_y_shift, 0]) cube([conn_cut_width, wall_interface_thick+0.2, conn_h_inner+2], center=true); 
            }
        }
    }
}

module rounded_frame_center(w, d, thick, h, r) {
    difference() { rounded_cube_center(w, d, h, r); translate([0,0,-1]) rounded_cube_center(w - thick*2, d - thick*2, h+2, r); }
}

module rounded_cube_center(x,y,z,r) {
    translate([-x/2, -y/2, 0]) hull() { translate([r,r,0]) cylinder(r=r, h=z); translate([x-r,r,0]) cylinder(r=r, h=z); translate([r,y-r,0]) cylinder(r=r, h=z); translate([x-r,y-r,0]) cylinder(r=r, h=z); }
}