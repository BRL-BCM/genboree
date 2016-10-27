package org.genboree.util;

import javax.mail.*;
import javax.mail.event.TransportEvent;
import javax.mail.event.TransportListener;
import javax.mail.internet.AddressException;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Date;
import java.util.Properties;
import java.util.Vector;


public class SendMail implements TransportListener
{
  protected String host;

  protected Vector addrTo;
  protected Vector addrCc;
  protected Vector addrBcc;

  protected Vector addrSent;
  protected Vector addrUnsent;
  protected Vector errMsgs;

  protected InternetAddress[] from;
  protected InternetAddress[] replyTo;
  protected String subj;
  protected String body;

  private boolean status = false;

  public SendMail() { init(); }

  public String[] getErrors()
  {
    if( errMsgs.size() == 0 ) return null;
    String[] rc = new String[ errMsgs.size() ];
    errMsgs.copyInto( rc );
    return rc;
  }

  protected String[] getAddresses( Vector v )
  {
    String[] rc = new String[ v.size() ];
    for( int i=0; i<v.size(); i++ )
      rc[i] = v.elementAt(i).toString();
    return rc;
  }

  public String[] getSent()
  {
    return getAddresses( addrSent );
  }

  public String[] getUnsent()
  {
    return getAddresses( addrUnsent );
  }

  public void clearErrors() { errMsgs = new Vector(); }

  public void init()
  {
    host = null;
    from = null;
    replyTo = null;
    subj = null;
    body = null;
    addrTo = new Vector();
    addrCc = new Vector();
    addrBcc = new Vector();
    addrSent = new Vector();
    addrUnsent = new Vector();
    errMsgs = new Vector();
  }

  public void setHost( String host ) { this.host = host; }

  public void setFrom( String from )
  {
    try
    {
      this.from = InternetAddress.parse(from, false);
    } catch( AddressException aex )
    {
      errMsgs.addElement( "Invalid Sender: <"+from+">" );
      errMsgs.addElement( " -- "+aex.getMessage() );
      this.from = null;
    } catch( Exception ex )
    {
      this.from = null;
    }
  }
  public void setReplyTo( String replyTo )
  {
    try
    {
      this.replyTo = InternetAddress.parse(replyTo, false);
    } catch( AddressException aex )
    {
      errMsgs.addElement( "Invalid Reply-To address: <"+replyTo+">" );
      errMsgs.addElement( " -- "+aex.getMessage() );
      this.replyTo = null;
    } catch( Exception ex )
    {
      this.replyTo = null;
    }
  }
  public void setSubj( String subj ) { this.subj = subj; }
  public void setBody( String body ) { this.body = body; }

  protected void addRecipient( String sadr, Vector v )
  {
    if( sadr == null || sadr.trim().length() == 0 ) return;
    try
    {
      InternetAddress[] iadrs = InternetAddress.parse( sadr, false );
      for( int i=0; i<iadrs.length; i++ ) v.addElement( iadrs[i] );
    } catch( AddressException aex )
    {
      errMsgs.addElement( "Invalid Recipient(s): <"+sadr+">" );
      errMsgs.addElement( " -- "+aex.getMessage() );
    } catch( Exception ex ) {}
  }

  public void addTo( String sadr ) { addRecipient(sadr, addrTo); }
  public void addCc( String sadr ) { addRecipient(sadr, addrCc); }
  public void addBcc( String sadr ) { addRecipient(sadr, addrBcc); }

  public boolean   go()
  {
    status = false;

    if( addrTo.size() == 0 && addrCc.size() == 0 && addrBcc.size() == 0)
    {
      errMsgs.addElement( "No one recipient was specified" );
      return false;
    }

    Properties props = new Properties();
    props.put( "mail.smtp.host", host );
    // Default mail.smtp.localhost is null in some cases...Java tries to get from /etc/hosts but not always working
    props.put( "mail.smtp.localhost", GenboreeConfig.getConfigParam("machineName") ) ;

    Session session = Session.getInstance(props, null);
    // System.err.println("^^^^^^ session mail.smtp.localhost: " + session.getProperty("mail.smtp.localhost")) ;

    session.setDebug( false );
    Transport trans = null;

    addrSent = new Vector();
    addrUnsent = new Vector();

    try
    {
      Message msg = new MimeMessage(session);

      if( from == null || from.length == 0 ) msg.setFrom();
      else msg.setFrom( from[0] );

      if( replyTo != null && replyTo.length > 0 )
      try{ msg.setReplyTo( replyTo ); } catch( Throwable t ) {}

      InternetAddress[] addrs = new InternetAddress[ addrTo.size() ];
      addrTo.copyInto( addrs );
      msg.setRecipients( Message.RecipientType.TO, addrs );
      addrs = new InternetAddress[ addrCc.size() ];
      addrCc.copyInto( addrs );
      msg.setRecipients( Message.RecipientType.CC, addrs );

      InternetAddress toAddr = null;

      // genboree_admin@genboree.org always gets a copy of all outgoing email
      this.addBcc(GenboreeConfig.getConfigParam("gbBccAdress")) ;

      Vector v = new Vector();
      int i;
      for( i=0; i<addrTo.size(); i++ ) v.addElement( addrTo.elementAt(i) );
      for( i=0; i<addrCc.size(); i++ ) v.addElement( addrCc.elementAt(i) );
      for( i=0; i<addrBcc.size(); i++ ) v.addElement( addrBcc.elementAt(i) );

      addrs = new InternetAddress[ v.size() ];
      v.copyInto( addrs );


      ArrayList validList = new ArrayList ();
        String hostName = null;
        String emailAddress = null;
        int index = -1;
      for ( i =0; i< addrs.length; i++) {
          emailAddress = addrs[i].getAddress();
          if (emailAddress != null){
                hostName = null;
                index  = emailAddress.indexOf('@');
                if (index>0)
                hostName = emailAddress.substring(index+1) ;


                if (hostName != null )
                {
                  // THIS DOESN'T WORK ON ALL ADDRESSES
                  // InetAddress.getByName(hostName) ;
                  // Use GenboreeUtil.validateEmailHost() instead:
                  if(GenboreeUtils.validateEmailHost(addrs[i].getAddress()))
                  {
                    validList.add (addrs[i]);
                  }
                  else
                  {
                    System.err.println(" unknow host from ex "  +  hostName + " from email " + emailAddress);
                    errMsgs.add( emailAddress);
                    continue;
                  }
                }
          }
      }

       if (!validList.isEmpty()) {
           addrs =(InternetAddress[]) validList.toArray(new InternetAddress[validList.size()]);
       }

         if( addrs.length > 0 ) toAddr = addrs[0];
        else
         return false;
      msg.setSubject( subj );
      msg.setSentDate( new Date() );
      msg.setContent( body, "text/plain" );
      msg.saveChanges();

      trans = session.getTransport( toAddr );

      trans.addTransportListener( this );
      trans.connect();
      trans.sendMessage( msg, addrs );

      try{ Thread.sleep(5); } catch( InterruptedException e ) {}
    }


    catch( MessagingException mex )
    {
      try{ Thread.sleep(5); } catch( InterruptedException e ) {}
      errMsgs.addElement( mex.getMessage() );

      Exception ex = mex;
      while( ex != null )
      {
        if( ex instanceof SendFailedException)
        {
          SendFailedException sfex = (SendFailedException)ex;

          registerAddresses( sfex.getInvalidAddresses(), addrUnsent );
          registerAddresses( sfex.getValidUnsentAddresses(), addrUnsent );
          registerAddresses( sfex.getValidSentAddresses(), addrSent );
          ex = sfex.getNextException();
        }
        else
        {
          if( ex != mex ) errMsgs.addElement( ex.getMessage() );
          ex = null;
        }
      }

    } finally
    {
      try
      {
        trans.close();
      } catch( Throwable t ) {}
    }

    return status;
  }

  protected void registerAddresses( Address[] addrs, Vector v )
  {
    if( addrs == null ) return;
    for( int i=0; i<addrs.length; i++ )
      if( !v.contains(addrs[i]) ) v.addElement( addrs[i] );
  }

  // implement TransportListener interface
  public void messageDelivered(TransportEvent e)
  {
    status = true;
    registerAddresses( e.getValidSentAddresses(), addrSent );
  }
  public void messageNotDelivered(TransportEvent e)
  {
    status = false;
    registerAddresses( e.getValidUnsentAddresses(), addrUnsent );
  }
  public void messagePartiallyDelivered(TransportEvent e) {}

/*
  public static void main( String[] args )
  {
    SendMail m = new SendMail();

    m.setHost( "mail.bcm.tmc.edu" );

    m.setFrom( "\"A.Volkov (work)\" <avolkov@bcm.tmc.edu>" );
    m.setReplyTo( "\"A.Volkov (work)\" <avolkov@bcm.tmc.edu>" );
    m.addTo( "\"Andrei I. Volkov\" <andrsib@hotmail.com>" );

    m.setSubj( "Test Java Mail(TM)" );

    m.setBody( "Hi,\n\n"+
      "If you have received this email, this means that my JavaMail-based\n"+
      "email sender class works fine.\n"+
      "Andrei I. Volkov"
    );

    System.out.println( "m.go() returns <"+m.go()+">" );

    int i;
    String[] msgs = m.getSent();
    if( msgs.length > 0 )
    {
      System.out.println( "Sent successfully to:" );
      for( i=0; i<msgs.length; i++ )
        System.out.println( "  "+msgs[i] );
    }
    msgs = m.getUnsent();
    if( msgs.length > 0 )
    {
      System.out.println( "Not sent to:" );
      for( i=0; i<msgs.length; i++ )
        System.out.println( "  "+msgs[i] );
    }
    msgs = m.getErrors();
    if( msgs != null && msgs.length > 0 )
    {
      System.out.println( "Error messages:" );
      for( i=0; i<msgs.length; i++ )
        System.out.println( "  "+(i+1)+". "+msgs[i] );
    }

  }
*/

}
